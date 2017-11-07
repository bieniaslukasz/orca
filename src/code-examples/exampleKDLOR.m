addpath ../Algorithms/

% Load the different partitions of the dataset
load ../../exampledata/1-holdout/toy/matlab/train_toy.0
load ../../exampledata/1-holdout/toy/matlab/test_toy.0

% "patterns" refers to the input variables and targets to the output one
train.patterns = train_toy(:,1:end-1);
train.targets = train_toy(:,end);
test.patterns = test_toy(:,1:end-1);
test.targets = test_toy(:,end);

% Create the algorithm object
kdlorAlgorithm = KDLOR('rbf','quadprog');

% Parameter C (Cost)
param(1) = 10;

% Parameter k (kernel width)
param(2) = 0.1;

% Parameter u (to avoid singularities)
param(3) = 0.001;

% Running the algorithm
info = kdlorAlgorithm.runAlgorithm(train,test,param);

accTrain = sum(train.targets==info.predictedTrain)/size(train.targets,1);
accTest = sum(test.targets==info.predictedTest)/size(test.targets,1);

% Reporting accuracy
fprintf('Accuracy Train %f, Accuracy Test %f\n',accTrain,accTest);