clear variables;
close all;
clc;

run_timings   = 1; % set this variable equal to 1 to recompute the timings in Table 1

if run_timings==1
    
message = 'Timings depend on the specific machine and on CPU usage. One should expect to replicate a similar pattern to that reported on Table 1 using a MacBook Pro with 2.3GHz Intel i7 processor and 16GB of RAM.';
display(message);
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/5variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/5variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/5variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/5variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/5variables/run_mainfile_timing_5.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/6variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/6variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/6variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/6variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/6variables/run_mainfile_timing_5.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/7variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/7variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/7variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/7variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/4_lags_3_signs_1_zero/7variables/run_mainfile_timing_5.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/5variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/5variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/5variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/5variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/5variables/run_mainfile_timing_5.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/6variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/6variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/6variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/6variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/6variables/run_mainfile_timing_5.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/7variables/run_mainfile_timing_1.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/7variables/run_mainfile_timing_2.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/7variables/run_mainfile_timing_3.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/7variables/run_mainfile_timing_4.m'])
currentFolder = pwd;
run([currentFolder,'/12_lags_3_signs_3_zeros/7variables/run_mainfile_timing_5.m'])

end

currentFolder = pwd;
%% Report timings
load([currentFolder,'/4_lags_3_signs_1_zero/5variables/results/timing_one.mat'])
t11=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/5variables/results/timing_two.mat'])
t21=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/5variables/results/timing_three.mat'])
t31=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/5variables/results/timing_four.mat'])
t41=tElapsed;
t61=count;
t71=ne/count;
load([currentFolder,'/4_lags_3_signs_1_zero/5variables/results/timing_five.mat'])
t51=tElapsed;

load([currentFolder,'/4_lags_3_signs_1_zero/6variables/results/timing_one.mat'])
t12=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/6variables/results/timing_two.mat'])
t22=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/6variables/results/timing_three.mat'])
t32=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/6variables/results/timing_four.mat'])
t42=tElapsed;
t62=count;
t72=ne/count;
load([currentFolder,'/4_lags_3_signs_1_zero/6variables/results/timing_five.mat'])
t52=tElapsed;

load([currentFolder,'/4_lags_3_signs_1_zero/7variables/results/timing_one.mat'])
t13=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/7variables/results/timing_two.mat'])
t23=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/7variables/results/timing_three.mat'])
t33=tElapsed;
load([currentFolder,'/4_lags_3_signs_1_zero/7variables/results/timing_four.mat'])
t43=tElapsed;
t63=count;
t73=ne/count;
load([currentFolder,'/4_lags_3_signs_1_zero/7variables/results/timing_five.mat'])
t53=tElapsed;


load([currentFolder,'/12_lags_3_signs_3_zeros/5variables/results/timing_one.mat'])
t14=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/5variables/results/timing_two.mat'])
t24=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/5variables/results/timing_three.mat'])
t34=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/5variables/results/timing_four.mat'])
t44=tElapsed;
t64=count;
t74=ne/count;
load([currentFolder,'/12_lags_3_signs_3_zeros/5variables/results/timing_five.mat'])
t54=tElapsed;

load([currentFolder,'/12_lags_3_signs_3_zeros/6variables/results/timing_one.mat'])
t15=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/6variables/results/timing_two.mat'])
t25=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/6variables/results/timing_three.mat'])
t35=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/6variables/results/timing_four.mat'])
t45=tElapsed;
t65=count;
t75=ne/count;
load([currentFolder,'/12_lags_3_signs_3_zeros/6variables/results/timing_five.mat'])
t55=tElapsed;

load([currentFolder,'/12_lags_3_signs_3_zeros/7variables/results/timing_one.mat'])
t16=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/7variables/results/timing_two.mat'])
t26=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/7variables/results/timing_three.mat'])
t36=tElapsed;
load([currentFolder,'/12_lags_3_signs_3_zeros/7variables/results/timing_four.mat'])
t46=tElapsed;
t66=count;
t76=ne/count;
load([currentFolder,'/12_lags_3_signs_3_zeros/7variables/results/timing_five.mat'])
t56=tElapsed;

Timings  = round([t11 t12 t13 t14 t15 t16
     t21 t22 t23 t24 t25 t26
     t31 t32 t33 t34 t35 t36
     t41 t42 t43 t44 t45 t46
     t51 t52 t53 t54 t55 t56],0);
count = round([t61 t62 t63 t64 t65 t66],2);
ne = round([t71 t72 t73 t74 t75 t76],2);
 
display(Timings)
display(count)
display(ne)
display('Done.')

