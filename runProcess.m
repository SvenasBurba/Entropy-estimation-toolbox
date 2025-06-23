% script runProcessOCV.m
%   Loads data from OCV lab tests done for several cells at several 
%   different temperatures, then calls processOCV.m to create the OCV
%   relationship, then saves the model to a model file.
%   Ref: Plett, Gregory L., "Battery Management Systems, Volume I,
%   Battery Modeling," Artech House, 2015

clear;
cellIDs = {'MCellGITT'}; % Identifiers for each cell ,'LFPHC'
% data files for each cell available at these temperatures
temps = {[45 25 0]};,% LFPHC %C6HC,[25] 
           
% minimum and maximum voltages for each cell, used for plotting results       
minV = [2.5];%,0.005
maxV = [3.65];%,1.5

% --------------------------------------------------------------------
% Load raw data from cell tests, then process
% --------------------------------------------------------------------
for theID = 1:length(cellIDs), % loop over all cells
  dirname = cellIDs{theID}; cellID = dirname;
  ind = find(dirname == '_'); % if there is a "_", delete it
  if ~isempty(ind), dirname = dirname(1:ind-1); end
  OCVDir = sprintf('%s_OCV',dirname); % folder in which to find data
  if ~exist(OCVDir,'dir'),
    error(['Folder "%s" not found in current folder.\n' ...
      'Please change folders so that "%s" is in the current '...
      'folder and re-run runProcessOCV.'],OCVDir,OCVDir); %#ok<SPERR>
  end
  
  filetemps = temps{theID}(:);  % data exists at these temperatures
  numtemps = length(filetemps); % number of data sets
  data = zeros([0 numtemps]);   % initialize data to zero

  for k = 1:numtemps,           % load the data files into the "data" var
    if filetemps(k) < 0,        % if temperature is negative, then
      filename = sprintf('%s/%s_OCV_N%02d.mat',... % look for this file
        OCVDir,cellID,abs(filetemps(k)));
    else                        % if temperature is positive, then
      filename = sprintf('%s/%s_OCV_P%02d.mat',... % look for this file
        OCVDir,cellID,filetemps(k));
    end
    load(filename);             % load OCV data file
    data(k).temp = filetemps(k);       % save temperature of test
    data(k).script1 = OCVData.script1; % save the four scripts
    data(k).script3 = OCVData.script3;
  end

  % then, call "processOCV" to do the actual data processing
  model = process_function(data,cellID,minV(theID),maxV(theID),1);
  save(sprintf('%smodel-ocv.mat',cellID),'model'); % save model file
end
%Makes a table variable with OCP and SOC
OCPTable = table(model.SOCaprox,model.OCVaprox);
dUdT_Table = table(model.SOC, model.OCVrel);
%'writebale' function can save the OCP, dU/dT and SOC table as .csv or other format for
%to be used as an import for equilibrium potential interpolation for
%electrodes

%writetable(OCPTable, 'LFPv1.2_OCV/LFPv1.2_OCP 1.csv')

%plot dU/dT curve for visualization
figure
plot(model.SOC, (1000*model.OCVrel))
grid on
set(gca, "FontSize",14)
title('Entropy figure from 45, 25 and 0 degC GITT data',FontSize=16)
xlabel('SOC [%]', FontSize=14)
ylabel('dU/dT [mV/K]',FontSize=14)

