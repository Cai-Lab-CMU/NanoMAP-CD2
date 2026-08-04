%
%  Imaris XTension: Distance Transform In and Out for Imaris 10.0.0
%
%  Copyright Bitplane AG 2011
%  modified by Matthew J. Gastinger 1/14/2013
%  modified by En Cai 07/09/2025
%
%  Installation:
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
% 
%<CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Distance Transform In and Out" icon="Matlab">
%          <Command>MatlabXT::XTDistanceTransformInAndOut(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Distance Transform In and Out" icon="Matlab">
%            <Command>MatlabXT::XTDistanceTransformInAndOut(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%Description
%
%This XTension creates a new channel with distance transformation in 
%(negative values) and out (positive values) of the cell surface.
%
%Note: this XTension processes surface whose name contain "Cell Export". If
%there are more than one surface meets the condition, it process the first
%one. 
%

function XTDistanceTransformInAndOut(aImarisApplicationID)

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  if exist('ImarisLib','class') == 0
    javaaddpath ImarisLib.jar
  end
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end

vImarisDataSet = vImarisApplication.GetDataSet.Clone;
%Convert dataset to 32bit float
vFloatType = vImarisDataSet.GetType.eTypeFloat;
vImarisDataSet.SetType(vFloatType);

% the user has to create a scene with some surfaces
vSurpassScene = vImarisApplication.GetSurpassScene;

if isequal(vSurpassScene, [])
  disp('No surface found. Please create some Surfaces in the Surpass scene!');
  return;
end

% Get the list of all surface objects
nObjects = vSurpassScene.GetNumberOfChildren;

vSurfaceList = {};  % Cell array to store all surfaces
vSurfaceNames = {};

for idx = 0:(nObjects - 1)
    vObject = vSurpassScene.GetChild(idx);
    surfaceName = char(vObject.GetName);
    
    % Check if the object is a surface
    if vImarisApplication.GetFactory.IsSurfaces(vObject)
        if contains(surfaceName, 'Cell Export')
            vSurfaceList{end+1} = vObject;
            vSurfaceNames{end+1} = surfaceName;
        end
    end
end

% Check if there is surface "Cell Export"
if isempty(vSurfaceList)
  disp('Cannot find surfaces exported from Cell.');
  return;
end

% Select the first surface that contain "Cell Export"
vSurface = vImarisApplication.GetFactory.ToSurfaces(vSurfaceList{1});
clear vSurfaceList nObjects

vDataMin = [vImarisDataSet.GetExtendMinX, vImarisDataSet.GetExtendMinY, vImarisDataSet.GetExtendMinZ];
vDataMax = [vImarisDataSet.GetExtendMaxX, vImarisDataSet.GetExtendMaxY, vImarisDataSet.GetExtendMaxZ];
vDataSize = [vImarisDataSet.GetSizeX, vImarisDataSet.GetSizeY, vImarisDataSet.GetSizeZ];

vProgressDisplay = waitbar(0, 'Distance Transform: Preparation');

% Create two new channels where the result will be sent
vNumberOfChannels = vImarisDataSet.GetSizeC;
vImarisDataSet.SetSizeC(vNumberOfChannels + 3); % 2 channels: Out, In 

vImarisDataSet.SetChannelName(vNumberOfChannels,['Distance to ', char(vSurface.GetName)]);
vImarisDataSet.SetChannelColorRGBA(vNumberOfChannels, 255*256*256);

vImarisDataSet.SetChannelName(vNumberOfChannels+1,['Distance 2 ', char(vSurface.GetName)]);
vImarisDataSet.SetChannelColorRGBA(vNumberOfChannels+1, 255*256*256);

vImarisDataSet.SetChannelName(vNumberOfChannels+2,['Distance 3 ', char(vSurface.GetName)]);
vImarisDataSet.SetChannelColorRGBA(vNumberOfChannels+2, 255*256*256);

vSizeT = vImarisDataSet.GetSizeT;
vSizeZ = vImarisDataSet.GetSizeZ;

for vTime = 0:vSizeT-1
    % Get the mask DataSet
    vMaskDataSet = vSurface.GetMask( ...
      vDataMin(1), vDataMin(2), vDataMin(3), ...
      vDataMax(1), vDataMax(2), vDataMax(3), ...
      vDataSize(1), vDataSize(2), vDataSize(3), vTime);

    for vIndexZ = 1:vDataSize(3)
      vSlice = vMaskDataSet.GetDataSliceBytes(vIndexZ-1, 0, 0);
      vSlice = vSlice ~= 1;
      if strcmp(vImarisDataSet.GetType,'eTypeUInt8')
        % Ch1
          vImarisDataSet.SetDataSliceBytes(vSlice, ...
          vIndexZ-1, vNumberOfChannels+1, vTime);
        % Ch2
        vImarisDataSet.SetDataSliceBytes(vSlice, ...
          vIndexZ-1, vNumberOfChannels+2, vTime);
      elseif strcmp(vImarisDataSet.GetType,'eTypeUInt16')
        % Ch1
          vImarisDataSet.SetDataSliceShorts(vSlice, ...
          vIndexZ-1, vNumberOfChannels+1, vTime);
        % Ch2
          vImarisDataSet.SetDataSliceShorts(vSlice, ...
          vIndexZ-1, vNumberOfChannels+2, vTime);
      elseif strcmp(vImarisDataSet.GetType,'eTypeFloat')
        % Ch1
          vImarisDataSet.SetDataSliceFloats(vSlice, ...
          vIndexZ-1, vNumberOfChannels+1, vTime);
        % Ch2
          vImarisDataSet.SetDataSliceFloats(vSlice, ...
          vIndexZ-1, vNumberOfChannels+2, vTime);
      end
    end
    clear vSlice
  
  waitbar((vTime+1)/vSizeT/2, vProgressDisplay);
end

% Clean up 
clear vMaskDataSet

waitbar(0.5, vProgressDisplay, 'Distance Transform: Calculation');
vImarisApplication.GetImageProcessing.DistanceTransformChannel( ...
  vImarisDataSet, vNumberOfChannels+1, 1, false);
vImarisApplication.GetImageProcessing.DistanceTransformChannel( ...
  vImarisDataSet, vNumberOfChannels+2, 1, true);

%
for vTime = 0:vSizeT-1
    if strcmp(vImarisDataSet.GetType,'eTypeUInt8')
        % Out - In
        for vSlice = 0:vSizeZ-1
            distTranAll = vImarisDataSet.GetDataSliceBytes(vSlice, vNumberOfChannels+2, vTime)...
                - vImarisDataSet.GetDataSliceBytes(vSlice, vNumberOfChannels+1, vTime);
            vImarisDataSet.SetDataSliceBytes(distTranAll, vSlice, vNumberOfChannels, vTime);
        end
    elseif strcmp(vImarisDataSet.GetType,'eTypeUInt16')
        % Out - In
        for vSlice = 0:vSizeZ-1
            distTranAll = vImarisDataSet.GetDataSliceShorts(vSlice, vNumberOfChannels+2, vTime)...
                - vImarisDataSet.GetDataSliceShorts(vSlice, vNumberOfChannels+1, vTime);
            vImarisDataSet.SetDataSliceShorts(distTranAll, vSlice, vNumberOfChannels, vTime);
        end
    elseif strcmp(vImarisDataSet.GetType,'eTypeFloat')
        % Out - In
        for vSlice = 0:vSizeZ-1
            distTranAll = vImarisDataSet.GetDataSliceFloats(vSlice, vNumberOfChannels+2, vTime)...
                - vImarisDataSet.GetDataSliceFloats(vSlice, vNumberOfChannels+1, vTime);
            vImarisDataSet.SetDataSliceFloats(distTranAll, vSlice, vNumberOfChannels, vTime);
        end
    end
end

% Delete the last two channels (DT-In, DT-Out)
vImarisDataSet.Crop(0,vDataSize(1),0,vDataSize(2),0,vDataSize(3),0,vNumberOfChannels+1,0,vSizeT)

% Clean up 
clear distTranAll

waitbar((vTime+1)/vSizeT/2, vProgressDisplay);

waitbar(1, vProgressDisplay);
vImarisApplication.SetDataSet(vImarisDataSet);
close(vProgressDisplay);

clear vImarisDataSet
end






