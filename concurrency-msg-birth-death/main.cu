#include <cstdio>
#include <cstdlib>
#include <iostream>
#include <fstream>

#include "flamegpu/flame_api.h"

/**
 * Simple Model demosntrating concurrency within a FLAMEGPU2 model, using mesasge lists and DAG based specificaiton.
 *  
 */

const int CONCURRENCY_DEGREE = 4;

// const int WARMUP_REPETITIONS = 1;
// const int TIMING_REPETITIONS = 3;
const int WARMUP_REPETITIONS = 0;
const int TIMING_REPETITIONS = 1;

// const float SPEEDUP_THRESHOLD = 1.5;


/** 
 * Utility function to time N repetitions of a simulation, returning the mean (but skipping the first)
 */
float meanSimulationTime(const int WARMUP_REPETITIONS, const int REPETITIONS, CUDASimulation &s, std::vector<AgentVector *> const &populations) {
    float total_time = 0.f;
    for (int r = 0; r < REPETITIONS + WARMUP_REPETITIONS; r++) {
        // re-set each population
        for (AgentVector* pop : populations) {
            s.setPopulationData(*pop);
        }
        // Run and time the simulation
        s.simulate();
        // Store the time if not the 0th rep of the model.
        if (r >= WARMUP_REPETITIONS) {
            total_time += s.getElapsedTimeSimulation();
        }
    }
    return total_time / REPETITIONS;
}

/** 
 * Utility function checking for a speedup after running a sim with and without concurrency.
 */
float concurrentLayerSpeedup(const int WARMUP_REPETITIONS, const int REPETITIONS, CUDASimulation &s, std::vector<AgentVector*> const &populations) {
    // Set a single step.
    s.SimulationConfig().steps = 1;

    // Set the flag saying don't use concurrency.
    s.CUDAConfig().inLayerConcurrency = false;
    s.applyConfig();
    // EXPECT_EQ(s.CUDAConfig().inLayerConcurrency, false);

    // Time the simulation multiple times to get an average
    float mean_sequential_time = meanSimulationTime(WARMUP_REPETITIONS, REPETITIONS, s, populations);

    // set the flag saying to use streams for agnet function concurrency.
    s.CUDAConfig().inLayerConcurrency = true;
    s.applyConfig();
    // EXPECT_EQ(s.CUDAConfig().inLayerConcurrency, true);

    float mean_concurrent_time = meanSimulationTime(WARMUP_REPETITIONS, REPETITIONS, s, populations);

    printf("mean_sequential_time %f ms\n", mean_sequential_time);
    printf("mean_concurrent_time %f ms\n", mean_concurrent_time);

    // Calculate a speedup value.
    float speedup = mean_sequential_time / mean_concurrent_time;
    return speedup;
}

/**
 * Agent function which inputs from a Spatial3D message list + some slow work.
 * Agents then birth a new agent
 * And then they all die (for a stable population.)
 * This is unrealistic, but demonstrates the problem.
 */
FLAMEGPU_AGENT_FUNCTION(outputBirthDeath, MsgNone, MsgSpatial3D) {
    // Repeatedly do some pointless maths on the value in register
    // const int INTERNAL_REPETITIONS = 65536;
    const int INTERNAL_REPETITIONS = 4096; // Need to make the kernel long enough to ensure that concurrency is actually observed.
    for (int i = 0; i < INTERNAL_REPETITIONS; i++) {
        // Read and write all the way to global mem each time to make this intentionally slow
        float v = FLAMEGPU->getVariable<float>("v");
        FLAMEGPU->setVariable("v", v + v);
    }
    FLAMEGPU->message_out.setVariable("v", FLAMEGPU->getVariable<float>("v"));
    FLAMEGPU->message_out.setLocation(
        FLAMEGPU->getVariable<float>("x"),
        FLAMEGPU->getVariable<float>("y"),
        FLAMEGPU->getVariable<float>("z")
    );

    // Birth
    FLAMEGPU->agent_out.setVariable<float>("v", FLAMEGPU->getVariable<float>("v"));
    FLAMEGPU->agent_out.setVariable<float>("x", FLAMEGPU->getVariable<float>("x"));
    FLAMEGPU->agent_out.setVariable<float>("y", FLAMEGPU->getVariable<float>("y"));
    FLAMEGPU->agent_out.setVariable<float>("z", FLAMEGPU->getVariable<float>("z"));

    // Death
    return DEAD;
}

/**
 * Agent function which inputs from a Spatial3D message list + some slow work.
 */
FLAMEGPU_AGENT_FUNCTION(intput, MsgSpatial3D, MsgNone) {
    // Repeatedly do some pointless maths on the value in register
    // const int INTERNAL_REPETITIONS = 65536;
    const int INTERNAL_REPETITIONS = 4096; // Need to make the kernel long enough to ensure that concurrency is actually observed.
    for (int i = 0; i < INTERNAL_REPETITIONS; i++) {
        // Read and write all the way to global mem each time to make this intentionally slow
        float v = FLAMEGPU->getVariable<float>("v");
        FLAMEGPU->setVariable("v", v + v);
    }
    float vSum = 0.f;
    float agent_x = FLAMEGPU->getVariable<float>("x");
    float agent_y = FLAMEGPU->getVariable<float>("y");
    float agent_z = FLAMEGPU->getVariable<float>("z");
    for (const auto &message : FLAMEGPU->message_in(agent_x, agent_y, agent_z)) {
        vSum += message.getVariable<float>("v");
    }
    FLAMEGPU->setVariable("v", vSum);
    return ALIVE;
}


unsigned int fullUtilisationThreadCount(const int deviceIdx) {
    // Find the number of threads to max out the device if 100% utilisation is achieved.#
    cudaError_t status;
    int multiprocessors = 0;
    int maxThreadsPerSM = 0;
    status = cudaDeviceGetAttribute(&multiprocessors, cudaDevAttrMultiProcessorCount, deviceIdx);
    if(cudaSuccess != status) {
        fprintf(stdout, "Erorr getting cudaDevAttrMultiProcessorCount. %s:%d\n", __FILE__, __LINE__);
        exit(EXIT_FAILURE);
    }

    status = cudaDeviceGetAttribute(&maxThreadsPerSM, cudaDevAttrMaxThreadsPerMultiProcessor, deviceIdx);
    if(cudaSuccess != status) {
        fprintf(stdout, "Erorr getting cudaDevAttrMaxThreadsPerMultiProcessor. %s:%d\n", __FILE__, __LINE__);
        exit(EXIT_FAILURE);
    }

    unsigned int threads = multiprocessors * maxThreadsPerSM;
    return threads;
}


int main(int argc, const char ** argv) {

    const unsigned int totalThreads = fullUtilisationThreadCount(0);
    printf("Total Threads required: %u\n", totalThreads);

    // Each pop size is an equal fraction.
    const unsigned int POPULATION_SIZES = totalThreads / CONCURRENCY_DEGREE;
    printf("CONCURRENCY_DEGREE: %u\n", CONCURRENCY_DEGREE);
    printf("POPULATION_SIZES: %u\n", POPULATION_SIZES);

    const float MESSAGE_BOUNDS_MIN = 0.f;
    const float MESSAGE_BOUNDS_MAX = 9.f;
    const float MESSAGE_BOUNDS_RADIUS = 1.f;

    // Define a model with multiple agent types
    ModelDescription m("ConcurrentSpatial3DBirthDeath");

    // Create two layers.
    LayerDescription &layer0  = m.newLayer();
    LayerDescription &layer1  = m.newLayer();

    std::vector<AgentVector*> populations = std::vector<AgentVector*>();

    // Add a few agent types, each with a single agent function.
    for (int i = 0; i < CONCURRENCY_DEGREE; i++) {
        // Generate the agent type
        std::string agent_name("agent_" + std::to_string(i));
        std::string agent_function_out(agent_name + "_outputBirthDeath");
        std::string agent_function_in(agent_name + "_intput");
        std::string message_name(agent_name + "_messages");
        AgentDescription &a = m.newAgent(agent_name);
        a.newVariable<float>("v");
        a.newVariable<float>("x");
        a.newVariable<float>("y");
        a.newVariable<float>("z");

        MsgSpatial3D::Description &msg = m.newMessage<MsgSpatial3D>(message_name);
        msg.newVariable<float>("v");
        msg.setMin(MESSAGE_BOUNDS_MIN, MESSAGE_BOUNDS_MIN, MESSAGE_BOUNDS_MIN);
        msg.setMax(MESSAGE_BOUNDS_MAX, MESSAGE_BOUNDS_MAX, MESSAGE_BOUNDS_MAX);
        msg.setRadius(MESSAGE_BOUNDS_RADIUS);

        auto &f_out = a.newFunction(agent_function_out, outputBirthDeath);
        f_out.setMessageOutput(msg);
        f_out.setAgentOutput(a);
        f_out.setAllowAgentDeath(true);


        layer0.addAgentFunction(f_out);

        auto &f_in = a.newFunction(agent_function_in, intput);
        f_in.setMessageInput(msg);

        layer1.addAgentFunction(f_in);

        // Generate an iniital population.
        AgentVector* a_pop = new AgentVector(a, POPULATION_SIZES);
        // unsigned long int seed = s.getSimulationConfig().random_seed;
        unsigned long int seed = 12; // @todo - fixed seed for now. CLI not yet parsed here  
        std::default_random_engine rng(seed);
        std::uniform_real_distribution<float> dist(0.0f, 11.0f);
        for (unsigned int j = 0; j < POPULATION_SIZES; ++j) {
            auto agent = a_pop->at(j);
            agent.setVariable<float>("v", static_cast<float>(j));
            agent.setVariable<float>("x", dist(rng));
            agent.setVariable<float>("y", dist(rng));
            agent.setVariable<float>("z", dist(rng));
        }
        populations.push_back(a_pop);
    }

    // Convert the model to a simulation
    CUDASimulation s(m);

    // Run the simulation many times, with and without concurrency to get an accurate speedup
    float speedup = concurrentLayerSpeedup(WARMUP_REPETITIONS, TIMING_REPETITIONS, s, populations);
    // Assert that a speedup was achieved.
    printf("speedup %f\n", speedup);


    return EXIT_SUCCESS;
}
