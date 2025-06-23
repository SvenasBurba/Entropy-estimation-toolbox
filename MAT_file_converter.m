% MAT_file_converter:
% This utility script loads the Excel files produced by the Arbin cell 
% tester and converts them to MATLAB ".mat" files for easier access.
%   Ref: Plett, Gregory L., "Battery Management Systems, Volume I,
%   Battery Modeling," Artech House, 2015


cellIDs = {'MCellGITT'}; % Identifiers for each cell
order = [45 25 0];             % Temperatures for each 

% Column headers to look for and convert to ".mat" file
headers = {'Test_Time(s)','Step_Index','Current(A)','Voltage(V)',...
           'Charge_Capacity(Ah)','Discharge_Capacity(Ah)'};
% Corresponding MATLAB structure field names to use         
fields  = {'time','step','current','voltage','chgAh','disAh'};%,
% Field names to use for the four different testing scripts
stepFields = {'script1','script2','script3','script4'};%

for theID = 1:length(cellIDs),    % loop over all cell types
  data = [];                      % clear data structure and start fresh
  for theFile = 1:length(order),  % loop over all temperatures
    dirname = cellIDs{theID};     % folder name in which to look for data
    ind = find(dirname == '_');   % if there is a "_", delete it
    if ~isempty(ind), dirname = dirname(1:ind-1); end
    if order(theFile) < 0,        % if temperature is negative, then
      OCVPrefix = sprintf('%s_OCV/%s_OCV_N%02d',... % look for this file
        dirname,cellIDs{theID},abs(order(theFile)));
    else                          % if temperature is positive, then
      OCVPrefix = sprintf('%s_OCV/%s_OCV_P%02d',... % look for this file
        dirname,cellIDs{theID},order(theFile));
    end

    for theScript = [1,3]          % process data from all four scripts
      OCVData = [];               % clear structure and start fresh
      for theField = 1:length(fields), % initialize empty fields
        OCVData.(fields{theField}) = [];
        chargeData.(fields{theField}) = [];
      end

      OCVFile = sprintf('%s_S%d.xlsx',OCVPrefix,theScript); % file name
      [~,sheets] = xlsfinfo(OCVFile);   % get names of sheets in file
      fprintf('Reading %s\n',OCVFile);  % status update for the impatient
      for theSheet = 1:length(sheets),  % loop over all sheets
        if strcmp(sheets{theSheet},'Info'), continue; end % ignore "Info"
        fprintf('Processing sheet %s\n',sheets{theSheet}); % status
        [num,txt,raw] = xlsread(OCVFile,sheets{theSheet}); % read data
        for theHeader = 1:length(headers), % parse out data that we care 
          ind = strcmp(txt(1,:),headers{theHeader}); % about
          OCVData.(fields{theHeader}) = [OCVData.(fields{theHeader});
            num(:,ind == 1)];
        end
      end
      data.(stepFields{theScript}) = OCVData; % save in structure
    end
    outFile = sprintf('%s.mat',OCVPrefix); % create output filename
    OCVData = data;
    save(outFile,'OCVData');               % save output file
  end
end