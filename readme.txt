This tool box contains Matlab conversion and processing scripts to process and extract estimates for OCV, OCP and dU/dT with respect to SOC

"MAT_file_converter.m" script converts excel files into .mat format to be processing compatibility
Data requirements for processing:
(required)- Charge/discharge data sets must be 2 separate files noted with cellID, temperature index and charge or discharge indicator
	* file name format "CellID_OCV_TempIndex_charge/discharge index.xlsx"
	* Example: "TestCell_OCV_P25_S1.xlsx" Where "P25" is positive temperature index, for negative temperatures notation is "N". While 	discharge index is "S1" and Charge one is "S3"

(required)- Charge/discharge data with at least 1 rested recording at the beginning and end of dataset
(required)- Operation index column "1" notes pre-current application "2" current is applied "3" rest after current application
(required)- discharge and charge capacity columns in [Ah], must be two separate columns in both charge and discharge datasets
(required)- Recorded voltage columns
(required)- Dataset at 25degC

Input CellID as string (as vector if multiple) and temperatures indexes (as vector if multiple) and execute the the script

After executing "MAT_file_converter.m" open "runProcess.m" input cellID as string (in vector form if multiple cells), temperature indexes also as vector (multiple vectors required for processing of multiple cells)

Executing the "runProcess.m" executes functions "process_function.m" and "OCVfromSOC_function.m"

"process_function.m" is responsible for IR blends, compensation and dU/dT, OCV/OCP estimation also containing the wanted SOC distribution for higher resolution estimations.

In case of needed changes in resolution:
	-SOC distribution variables are located at (Line 71) and (Line 236) for 25degC and other than 25degC data processing.

Adapting script to OCP estimation:
	-inverse the selection which data set it is being followed during interpolation of the estimated curve for 25degC data charge curve follow is at (line 138) and for discharge (line 141). For not 25degC data charge curve follow is at (Line 194) and for discharge (line 197) just reverse the "<,>" signs. Script then can estimate OCP and there respective du/dT   


"OCVfromSOC_function.m" is responsible for curve interpolation and extrapolation with respect to SOC and in case of missing data between charge and discharge curves.

After Execution of "runProcess.m" the OCV/OCP tables can be extracted as well as there respective dU/dT tables. 