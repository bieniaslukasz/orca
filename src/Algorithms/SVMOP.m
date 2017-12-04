classdef SVMOP < Algorithm
    %SVMOP Support vector machines using Frank & Hall method for ordinal
    % regression (by binary decomposition). This class uses libsvm-weights
    % for SVM training (https://www.csie.ntu.edu.tw/~cjlin/libsvm).
    %   SVMOP methods:
    %      runAlgorithm               - runs the corresponding algorithm,
    %                                   fitting the model and testing it in a dataset.
    %      train                      - Learns a model from data
    %      test                       - Performs label prediction
    %
    %   References:
    %     [1] E. Frank and M. Hall, "A simple approach to ordinal classification"
    %         in Proceedings of the 12th European Conference on Machine Learning,
    %         ser. EMCL'01. London, UK: Springer-Verlag, 2001, pp. 145–156.
    %         https://doi.org/10.1007/3-540-44795-4_13
    %     [2] W. Waegeman and L. Boullart, "An ensemble of weighted support
    %         vector machines for ordinal regression", International Journal
    %         of Computer Systems Science and Engineering, vol. 3, no. 1,
    %         pp. 47–51, 2009.
    %     [3] P.A. Gutiérrez, M. Pérez-Ortiz, J. Sánchez-Monedero,
    %         F. Fernández-Navarro and C. Hervás-Martínez
    %         Ordinal regression methods: survey and experimental study
    %         IEEE Transactions on Knowledge and Data Engineering, Vol. 28. Issue 1
    %         2016
    %         http://dx.doi.org/10.1109/TKDE.2015.2457911
    %
    %   This file is part of ORCA: https://github.com/ayrna/orca
    %   Original authors: Pedro Antonio Gutiérrez, María Pérez Ortiz, Javier Sánchez Monedero
    %   Citation: If you use this code, please cite the associated paper http://www.uco.es/grupos/ayrna/orreview
    %   Copyright:
    %       This software is released under the The GNU General Public License v3.0 licence
    %       available at http://www.gnu.org/licenses/gpl-3.0.html
    
    properties
        name_parameters = {'C','k'};
        parameters;
        weights = true;
        algorithmMexPath = fullfile(pwd,'Algorithms','libsvm-weights-3.12','matlab');
    end
    
    methods
        
        function obj = SVMOP(kernel)
            %SVR SVMOP an object of the class SVR and sets its default
            %   characteristics
            %   OBJ = SVR(KERNEL) builds SVR with KERNEL as kernel function
            obj.name = 'Frank Hall Support Vector Machines';
            if(nargin ~= 0)
                obj.kernelType = kernel;
            else
                obj.kernelType = 'rbf';
            end
        end
        
        function obj = defaultParameters(obj)
            %DEFAULTPARAMETERS It assigns the parameters of the algorithm
            %   to a default value.
            % cost
            obj.parameters.C = 10.^(-3:1:3);
            % kernel width
            obj.parameters.k = 10.^(-3:1:3);
        end
        
        function [mInf] = runAlgorithm(obj,train, test, parameters)
            %RUNALGORITHM runs the corresponding algorithm, fitting the
            %model and testing it in a dataset.
            %   mInf = RUNALGORITHM(OBJ, TRAIN, TEST, PARAMETERS) learns a
            %   model with TRAIN data and PARAMETERS as hyper-parameter
            %   values for the method. Test the generalization performance
            %   with TRAIN and TEST data and returns predictions and model
            %   in mInf structure
            nParam = numel(obj.name_parameters);
            if nParam~= 0
                parameters = reshape(parameters,[1,nParam]);
                param = cell2struct(num2cell(parameters(1:nParam)),obj.name_parameters,2);
            else
                param = [];
            end
            
            c1 = clock;
            [model,mInf.projectedTrain, mInf.predictedTrain] = obj.train(train,param);
            c2 = clock;
            mInf.trainTime = etime(c2,c1);
            
            c1 = clock;
            [mInf.projectedTest, mInf.predictedTest] = obj.test(test.patterns, model);
            c2 = clock;
            mInf.testTime = etime(c2,c1);
            mInf.model = model; 
        end
        
        
        function [model, projectedTrain, predictedTrain] = train( obj, train, param)
            %TRAIN trains the model for the SVR method with TRAIN data and
            %vector of parameters PARAMETERS. Return the learned model.
            if isempty(strfind(path,obj.algorithmMexPath))
                addpath(obj.algorithmMexPath);
            end
            classes = unique(train.targets);
            nOfClasses = numel(classes);
            patterns = train.patterns(train.targets==1,:);
            labels = train.targets(train.targets == 1);
            
            for i = 2:nOfClasses
                patterns = [patterns ; train.patterns(train.targets==i,:)];
                labels = [labels ; train.targets(train.targets == i)];
            end
            
            trainTargets = labels;
            
            models = cell(1, nOfClasses-1);
            for i = 2:nOfClasses
                
                etiquetas_train = [ ones(size(trainTargets(trainTargets<i))) ;  ones(size(trainTargets(trainTargets>=i)))*2];
                
                % Train
                options = ['-b 1 -t 2 -c ' num2str(param.C) ' -g ' num2str(param.k) ' -q'];
                if obj.weights
                    weightsTrain = obj.computeWeights(i-1,trainTargets);
                else
                    weightsTrain = ones(size(trainTargets));
                end
                models{i} = svmtrain(weightsTrain, etiquetas_train, train.patterns, options);
                if(numel(models{i}.SVs)==0)
                    disp('Something went wrong. Please check the training patterns.')
                end
            end
            
            model.models=models;
            model.algorithm = 'SVMOP';
            model.parameters = param;
            model.weights = obj.weights;
            model.nOfClasses = nOfClasses;
            [projectedTrain, predictedTrain] = obj.test(train.patterns,model);
            
            if ~isempty(strfind(path,obj.algorithmMexPath))
                rmpath(obj.algorithmMexPath);
            end
            
        end
        
        function [projected,predicted] = test(obj,test,model)
            %TEST predict labels of TEST patterns labels using MODEL.
            if isempty(strfind(path,obj.algorithmMexPath))
                addpath(obj.algorithmMexPath);
            end
            projected = zeros(model.nOfClasses, size(test,1));
            for i = 2:model.nOfClasses
                [pr, acc, probTs] = svmpredict(zeros(size(test,1),1),test,model.models{i},'-b 1');
                
                projected(i-1,:) = probTs(:,2)';
            end
            probts(1,:) = ones(size(projected(1,:))) - projected(1,:);
            for i=2:model.nOfClasses
                probts(i,:) =  projected(i-1,:) -  projected(i,:);
            end
            probts(model.nOfClasses,:) =  projected(model.nOfClasses-1,:);
            [aux, predicted] = max(probts);
            predicted = predicted';
            if ~isempty(strfind(path,obj.algorithmMexPath))
                rmpath(obj.algorithmMexPath);
            end
        end
        
        function [weights] = computeWeights(obj, p, targets)
            weights = ones(size(targets));
            weights(targets<=p) = (p+1-targets(targets<=p)) * size(targets(targets<=p),1) / sum(p+1-targets(targets<=p));
            weights(targets>p) = (targets(targets>p)-p) * size(targets(targets>p),1) / sum(targets(targets>p)-p);
        end
        
    end
    
end

