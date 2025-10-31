% function model=processOCV(data,cellID,minV,maxV,savePlots)
% 
% Inputs:
%   data = cell-test data passed in from runProcessOCV
%   cellID = cell identifier (string)
%   minV = minimum cell voltage to use in OCV relationship
%   maxV = maximum cell voltage to use in OCV relationship
%   savePlots = 0 or 1 ... set to "1" to save plots as files 
% Output:
%   model = data structure with information for recreating OCV
%
% Technical note: PROCESSOCV assumes that specific Arbin test scripts
% have been executed to generate the input files. "makeMATfiles.m" 
% converts the raw Excel data files into "MAT" format, where the MAT 
% files have fields for time, step, current, voltage, chgAh, and disAh
% for each script run.
%
% The results from four scripts are required at every temperature.  
% The steps in each script file are assumed to be:
%   Script 1 (thermal chamber set to test temperature):
%     Step 1: Rest @ 100% SOC to acclimatize to test temperature
%     Step 2: Discharge @ low rate (ca. C/30) to min voltage
%     Step 3: Rest ca. 0%
%   Script 2 (thermal chamber set to 25 degC):
%     Step 1: Rest ca. 0% SOC to acclimatize to 25 degC
%     Step 2: Discharge to min voltage (ca. C/3)
%     Step 3: Rest
%     Step 4: Constant voltage at vmin until current small (ca. C/30)
%     Steps 5-7: Dither around vmin
%     Step 8: Rest
%     Step 9: Constant voltage at vmin for 15 min
%     Step 10: Rest
%   Script 3 (thermal chamber set to test temperature):
%     Step 1: Rest at 0% SOC to acclimatize to test temperature
%     Step 2: Charge @ low rate (ca. C/30) to max voltage
%     Step 3: Rest
%   Script 4 (thermal chamber set to 25 degC):
%     Step 1: Rest ca. 100% SOC to acclimatize to 25 degC
%     Step 2: Charge to max voltage (ca. C/3)
%     Step 3: Rest
%     Step 4: Constant voltage at vmax until current small (ca. C/30)
%     Steps 5-7: Dither around vmax
%     Step 8: Rest
%     Step 9: Constant voltage at vmax for 15 min
%     Step 10: Rest
% 
% All other steps (if present) are ignored by PROCESSOCV.  The time 
% step between data samples is not critical since the Arbin integrates
% ampere-hours to produce the two Ah columns, and this is what is 
% necessary to generate the OCV curves.  The rest steps must 
% contain at least one data point each.

%   Ref: Plett, Gregory L., "Battery Management Systems, Volume I,
%   Battery Modeling," Artech House, 2015

function model=process_function_OCP(data,cellID,minV,maxV,savePlots)
  filetemps = [data.temp]; filetemps = filetemps(:);
  numtemps = length(filetemps); 
  
  % First, look for test(s) at 25 degC -- need this to compute coulombic
  % efficiency and capacity at 25 degC before continuing
  ind25 = find(filetemps == 25); 
  if isempty(ind25),
    error('Must have a test at 25degC');
  end
  not25 = find(filetemps ~= 25);

  % ------------------------------------------------------------------
  % Process 25 degC data to find raw OCV relationship and eta25
  % ------------------------------------------------------------------
  SOC = 0.001:0.001:1; % output SOC points for this step
  filedata = zeros([0 length(data)]);
  eta = zeros(size(filetemps)); % coulombic efficiency
  Q   = zeros(size(filetemps)); % apparent total capacity
  k = ind25;

  totDisAh = data(k).script1.dismAh(end) + ... % compute total discharge ampere hours
             data(k).script3.dismAh(end);
  totChgAh = data(k).script1.chgmAh(end) + ... % compute total charge ampere hours
             data(k).script3.chgmAh(end);
  %disp(totDisAh)
  %disp(totChgAh)
  eta25 = totDisAh/totChgAh; eta(k) = eta25;% 25 degC coulombic efficiency
  data(k).script1.chgmAh = data(k).script1.chgmAh*eta25; % adjust charge Ah in all scripts
  data(k).script3.chgmAh = data(k).script3.chgmAh*eta25; % per eta25
  %disp(eta25)

  % compute cell capacity at 25 degC (should be essentially same at all
  % temps, but we're computing them individually to check this)
  Q25 = data(k).script1.dismAh(end) - data(k).script1.chgmAh(end);
  Q(k) = Q25;

  indD  = find(data(k).script1.step == 2); % slow discharge step
  IR1Da = data(k).script1.voltage(indD(1)-1) - ... % i*R voltage drop at
          data(k).script1.voltage(indD(1));% beginning of dischg
  IR2Da = data(k).script1.voltage(indD(end-1)) - ... % same at end of 
          data(k).script1.voltage(indD(end));      % dischg
 
  indC  = find(data(k).script3.step == 2); % slow charge step
  IR1Ca = data(k).script3.voltage(indC(1)) - ...   % i*R voltage rise at
          data(k).script3.voltage(indC(1)-1);      % beginning of charge
  IR2Ca = data(k).script3.voltage(indC(end)) - ... % same at end of charge
      data(k).script3.voltage(indC(end-1));
  IR1D = min(IR1Da,2*IR2Ca); IR2D = min(IR2Da,2*IR1Ca); % put bounds on R
  IR1C = min(IR1Ca,2*IR2Da); IR2C = min(IR2Ca,2*IR1Da);
  
  blend = (0:length(indD)-1)/(length(indD)-1); % linear blending 0..1
  IRblend = IR1D + (IR2D-IR1D)*blend(:); % blend resistances
  disV = data(k).script1.voltage(indD) + IRblend; % approx dischg V and
  disV = cumsum(ones(size(disV)))*eps + disV;
  disZ = 1 - data(k).script1.dismAh(indD)/Q25;% soc at each point
  %disp(disZ)
  disZ = disZ + (1 - disZ(1)); 
  disZ = cumsum(ones(size(disZ)))*eps + disZ;
  filedata(k).disZ = disZ; 
  filedata(k).disV = data(k).script1.voltage(indD);
  %size(disZ)

  blend = (0:length(indC)-1)/(length(indC)-1); % linear blending 0..1
  IRblend = IR1C + (IR2C-IR1C)*blend(:);       % blend resistances
  chgV = data(k).script3.voltage(indC) - IRblend;% approx chg V and
  chgV= cumsum(ones(size(chgV)))*eps + chgV;
  %disp(chgV)
  chgZ = data(k).script3.chgmAh(indC)/Q25; % soc at each point
  %disp(chgZ)
  chgZ = chgZ - chgZ(1);
  chgZ = cumsum(ones(size(chgZ)))*eps + chgZ;
  filedata(k).chgZ = chgZ; 
  filedata(k).chgV = data(k).script3.voltage(indC);
  % compute voltage difference b/w charge and dischg @ 50% soc
  % force i*R compensated curve to pass half-way between each charge
  % and discharge at this point
  %disp(chgZ)
  %disp(chgV)
  %disp(disZ)

  deltaV50 =interp1(chgZ,chgV,0.5) - interp1(disZ,disV,0.5); 
  ind = find(chgZ > 0.5);
  vChg = chgV(ind) - chgZ(ind)*deltaV50;
  zChg = chgZ(ind);
  ind = find(disZ < 0.5);
  vDis = flipud(disV(ind) + (1 - disZ(ind))*deltaV50);
  zDis = flipud(disZ(ind));
  filedata(k).rawocv = interp1([zChg; zDis],[vChg; vDis],SOC,'linear','extrap');
  % "rawocv" now has our best guess of true OCV at this temperature
  filedata(k).temp = data(k).temp;
  
  % ------------------------------------------------------------------
  % Process other temperatures to find raw OCV relationship and eta
  % Everything that follows is same as at 25 degC, except we need to
  % compensate for different coulombic efficiencies eta at different
  % temperatures
  % ------------------------------------------------------------------
  for k = not25',    
    eta(k) = (data(k).script1.disAh(end) + ...
              data(k).script3.disAh(end))/ ...
             (data(k).script1.chgmAh(end) + ...
              data(k).script3.chgmAh(end));
    data(k).script1.chgmAh = eta(k)*data(k).script1.chgmAh;         
    data(k).script3.chgmAh = eta(k)*data(k).script3.chgmAh;         

    Q(k) = data(k).script1.disAh(end)- data(k).script1.chgmAh(end);
    indD = find(data(k).script1.step == 2); % slow discharge
    IR1D = data(k).script1.voltage(indD(1)-1) - ...
            data(k).script1.voltage(indD(1));
    IR2D = data(k).script1.voltage(indD(end)-1) - ...
            data(k).script1.voltage(indD(end));
    indC = find(data(k).script3.step == 2);
    IR1C = data(k).script3.voltage(indC(1)) - ...
            data(k).script3.voltage(indC(1)-1);
    IR2C = data(k).script3.voltage(indC(end)) - ...
            data(k).script3.voltage(indC(end)-1);
    IR1D = min(IR1D,2*IR2C); IR2D = min(IR2D,2*IR1C);
    IR1C = min(IR1C,2*IR2D); IR2C = min(IR2C,2*IR1D);

    blend = (0:length(indD)-1)/(length(indD)-1);
    IRblend = IR1D + (IR2D-IR1D)*blend(:);
    disV = data(k).script1.voltage(indD) + IRblend;
    disZ = 1 - data(k).script1.disAh(indD)/Q25;
    disZ = disZ + (1 - disZ(1));
    filedata(k).disZ = disZ; 
    filedata(k).disV = data(k).script1.voltage(indD);
    
    
    blend = (0:length(indC)-1)/(length(indC)-1);
    IRblend = IR1C + (IR2C-IR1C)*blend(:);
    chgV = data(k).script3.voltage(indC) - IRblend;
    chgZ = data(k).script3.chgmAh(indC)/Q25;
    chgZ = chgZ - chgZ(1);
    filedata(k).chgZ = chgZ; 
    filedata(k).chgV = data(k).script3.voltage(indC);

    deltaV50 = interp1(chgZ,chgV,0.5) - interp1(disZ,disV,0.5);
    ind = find(chgZ > 0.5);
    vChg = chgV(ind) - chgZ(ind)*deltaV50;
    zChg = chgZ(ind);
    ind = find(disZ < 0.5);
    vDis = flipud(disV(ind) + (1 - disZ(ind))*deltaV50);
    zDis = flipud(disZ(ind));
    filedata(k).rawocv = interp1([zChg; zDis],[vChg; vDis],SOC,'linear','extrap');
    filedata(k).temp = data(k).temp;
  end
  % ------------------------------------------------------------------
  % Use the SOC versus OCV data now available at each individual
  % temperature to compute an OCV0 and OCVrel relationship
  % ------------------------------------------------------------------
  % First, compile the voltages and temperatures into single arrays 
  % rather than structures
  Vraw = []; temps = []; 
  for k = 1:numtemps,
    if filedata(k).temp > 0,
      Vraw = [Vraw; filedata(k).rawocv]; %#ok<AGROW>
      temps = [temps; filedata(k).temp]; %#ok<AGROW>
    end
  end
  numtempskept = size(Vraw,1);
  % use linear least squares to determine best guess for OCV at 0 degC
  % and then the per-degree OCV change
  OCV0 = zeros(size(SOC)); OCVrel = OCV0;
   H = [ones([numtempskept,1]), temps];
  for k = 1:length(SOC),
      
    X = H\Vraw(:,k); % fit OCV(z,T) = 1*OCV0(z) + T*OCVrel(z)
    OCV0(k) = X(1); 
    OCVrel(k) = X(2);
  end
  disp(H)
  model.OCV0 = OCV0;
  model.OCVrel = OCVrel;
  model.SOC = SOC;
  model.Sapprox = OCVrel';
  % ------------------------------------------------------------------
  % Make SOC0 and SOCrel
  % Do same kind of analysis to find soc as a function of ocv
  % ------------------------------------------------------------------
  z = 0.001:0.001:1; % test soc vector
  v = minV-0.01:0.01:maxV+0.01;
  socs = [];
  for T = filetemps',
    v1 = OCVfromSOC_function(z,T,model);
    socs = [socs; interp1(v1,z,v)]; %#ok<AGROW>
  end
  SOC0 = zeros(size(v)); SOCrel = SOC0; 
  H = [ones([numtemps,1]), filetemps]; 
  for k = 1:length(v),
    X = H\socs(:,k); % fit SOC(v,T) = 1*SOC0(v) + T*SOCrel(v)
    SOC0(k) = X(1); 
    SOCrel(k) = X(2);
  end
  model.OCV = v;
  model.SOC0 = SOC0;
  model.SOCrel = SOCrel;
  
  % ------------------------------------------------------------------
  % Save other misc. data in structure
  % ------------------------------------------------------------------
  model.OCVeta = eta;
  model.OCVQ = Q;
  model.name = cellID;
  model.OCVaprox = flipud(v1)';
  model.SOCaprox = z';
  
  % ------------------------------------------------------------------
  % Plot some data...
  % ------------------------------------------------------------------
  % Fixed number of columns, adaptive number of rows
cols = 2;
rows = ceil(numtemps / cols);

% Create one figure with tiled layout
figure('Units','normalized','Position',[0.05 0.1 0.9 0.8]);
tiledlayout(rows, cols, 'TileSpacing', 'compact', 'Padding', 'compact');

    for k = 1:numtemps
        nexttile;  % Move to next subplot position
        
        % Plot model prediction and raw data
        plot(100*SOC, OCVfromSOC_function(SOC, filedata(k).temp, model), ...
             100*SOC, filedata(k).rawocv, 'LineWidth', 1.2);
        hold on
        plot(100*filedata(k).disZ, filedata(k).disV, 'k--', 'LineWidth', 1);
        plot(100*filedata(k).chgZ, filedata(k).chgV, 'k--', 'LineWidth', 1);
        
        % Labels and axes
        xlabel('SOC (%)');
        ylabel('OCP (V)');
        ylim([minV-0.1, maxV+0.1]);
        xlim([0, 100]);
        title(sprintf('%s OCP relationship at temp = %d°C', cellID, filedata(k).temp));
        
        % Compute and display RMS error
        err = filedata(k).rawocv - OCVfromSOC_function(SOC, filedata(k).temp, model);
        rmserr = sqrt(mean(err.^2));
        text(2, maxV-0.15, sprintf('RMS error = %4.1f (mV)', rmserr*1000), 'FontSize', 10);
        
        % Only one legend to save space
        if k == 1
            legend('Model prediction', 'Approximate OCV from data', ...
                   'Raw measured data', 'Location', 'southeast');
        end
        hold off
    end
    
    % Optional: save full grid figure
    if savePlots
        if ~exist('OCP_FIGURES', 'dir')
            mkdir('OCP_FIGURES');
        end
        filename = sprintf('OCP_FIGURES/%s_OCP_grid.png', cellID);
        exportgraphics(gcf, filename, 'Resolution', 300);
    end
end