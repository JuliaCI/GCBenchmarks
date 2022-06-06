using DifferentialEquations

function f(du,u,p,t)
  du[1] = p[1] * u[1] - p[2] * u[1]*u[2]
  du[2] = -3 * u[2] + u[1]*u[2]
end

function g(du,u,p,t)
  du[1] = p[3]*u[1]
  du[2] = p[4]*u[2]
end

p = [1.5,1.0,0.1,0.1];
prob = SDEProblem(f,g,[1.0,1.0],(0.0,10.0),p);

function prob_func(prob,i,repeat)
  x = 0.3rand(2)
  remake(prob,p=[p[1:2];x])
end

ensemble_prob = EnsembleProblem(prob,prob_func=prob_func);

include("../../utils.jl")

@gctime solve(ensemble_prob,SRIW1(),trajectories=1_000_000).u[end].u[end]


# Results on Julia master with 18 threads at time of PR:
┌─────────┬────────────┬─────────┬──────────────┬───────────────────┬──────────┬────────────┐
│         │ total time │ gc time │ max GC pause │ time to safepoint │ max heap │ percent gc │
│         │         ms │      ms │           ms │                ms │       MB │          % │
├─────────┼────────────┼─────────┼──────────────┼───────────────────┼──────────┼────────────┤
│ minimum │      44143 │   18857 │         9822 │                 0 │    34017 │         43 │
│  median │      44160 │   19057 │         9919 │                 0 │    34118 │         43 │
│ maximum │      44429 │   19152 │         9948 │                 0 │    34202 │         43 │
└─────────┴────────────┴─────────┴──────────────┴───────────────────┴──────────┴────────────┘

