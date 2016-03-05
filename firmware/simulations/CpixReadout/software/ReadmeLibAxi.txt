cp software/libAxiSim.so ../../build/PROJ_NAME/PROJ_NAME_project.sim/sim_1/behav/

echo $LD_LIBRARY_PATH
setenv LD_LIBRARY_PATH $LD_LIBRARY_PATH\:.
echo $LD_LIBRARY_PATH