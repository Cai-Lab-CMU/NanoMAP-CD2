%
% Function: distantTransformationSubVolume, used in the Imaris XTension
% Nearby Surfaces. 
%
% Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
% University, 2025/07.
%
% This function is called by the Imaris XTension Nearby Surfaces. It
% calculates signed distance transformation for a sub-surface of a surface
% object. 
%

function distTranAll = distantTransformationSubVolume(vImarisApplication, vDataSet, vSubMask, sizeX, sizeY, sizeZ, Xvoxelspacing, Yvoxelspacing, Zvoxelspacing)
% Create a subVolume the same size of the subMask
vFloatType = Imaris.tType.eTypeFloat;
vSubDataSet = vDataSet.Clone;
vSubDataSet.SetType(vFloatType);   % 4 channels: DT Out, In, Mask, Out-In
% Resize vSubDataSet to Mask size
vSubDataSet.Resize(0,int32(sizeX),0,int32(sizeY),0,int32(sizeZ),0, 2,0, 1); % set a initial size, with 2 ch and t
% Load SubSurf Mask as floats to the dataset
vSubMask = vSubMask ~= 1;
vSubDataSet.SetDataVolumeFloats(vSubMask, 0, 0);
vSubDataSet.SetDataVolumeFloats(vSubMask, 1, 0);

% Distance Transformation
vImarisApplication.GetImageProcessing.DistanceTransformChannel( ...
    vSubDataSet, 0, 1, false); % In
vImarisApplication.GetImageProcessing.DistanceTransformChannel( ...
    vSubDataSet, 1, 1, true);  % Out
% Out - In
distTranAll = vSubDataSet.GetDataVolumeFloats(1, 0)...
    - vSubDataSet.GetDataVolumeFloats(0, 0);

clear vSubDataSet
end