%
%  Surface Index Mask XTension for Imaris 10.0.0
%  Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
%  University, 2025/07.
%
%  This extension assigns index to sub-surfaces from the selected surface
%  object. For a sub-surface, all voxels within it are set to the value of 
%  the ID of this sub-surface. For sub-surface ID=0, voxel vaule is 0.1. 
%  Input: Imaris surface object with subsurfaces.
%  Output: Creates a new "mask" channel of the surface, where voxel values 
%  correspond to the ID of individule sub-surfaces. Save the cell array of 
%  vID_Mask to the data folder.  
%  Dependencies:
%   - Function: SurfaceIDMask.m
%   - Function: Submask2Fullmask.m
%   - Function: align2Fullmask.m
%
%  Note: This extension calls the other functions, make sure matlab 
%  can access these functions.   
%
%  Installation:
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%        <Item name="Surface Index Mask" icon="Matlab" tooltip="Create a new 3D channel combining the others using a regular expression.">
%          <Command>MatlabXT::XTSurfaceIndexMask(%i)</Command>
%        </Item>
%      </Menu>
%    </CustomTools>
%

function XTSurfaceIndexMaskSingleChannel(aImarisApplicationID)
% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end

% Check for the selected surface
% the user has to create a scene with some surfaces
vSurpassScene = vImarisApplication.GetSurpassScene;

if isequal(vSurpassScene, [])
    msgbox('Please create some Surfaces in the Surpass scene!');
    return;
end

% get all Surpass surfaces names
vSurfaces = vImarisApplication.GetFactory.ToSurfaces(vImarisApplication.GetSurpassSelection);
vSurfacesSelected = vImarisApplication.GetFactory.IsSurfaces(vSurfaces);

if vSurfacesSelected
    vScene = vSurfaces.GetParent;
else
    vScene = vImarisApplication.GetSurpassScene;
end

vNumberOfSurfaces = 0;
vSurfacesAll = {};
vNamesList = {};
vSurfacesList= {};
for vChildIndex = 1:vScene.GetNumberOfChildren
    vDataItem = vScene.GetChild(vChildIndex - 1);
    if vImarisApplication.GetFactory.IsSurfaces(vDataItem)
        vNumberOfSurfaces = vNumberOfSurfaces+1;
        vNamesList{vNumberOfSurfaces} = char(vDataItem.GetName);
        vSurfacesList{vNumberOfSurfaces} = vImarisApplication.GetFactory.ToSurfaces(vDataItem);
        vSurfacesAll{vNumberOfSurfaces, 1} = vNumberOfSurfaces;
        vSurfacesAll{vNumberOfSurfaces, 2} = vChildIndex;
        vSurfacesAll{vNumberOfSurfaces, 3} = char(vDataItem.GetName);
        vSurfacesAll{vNumberOfSurfaces, 4} = vImarisApplication.GetFactory.ToSurfaces(vDataItem);
    end
end

% Get dataset and related info
vImarisDataSet = vImarisApplication.GetDataSet.Clone;
vNumberOfChannels = vImarisDataSet.GetSizeC;
aSizeT = vImarisDataSet.GetSizeT;

vDataMin = [vImarisDataSet.GetExtendMinX, vImarisDataSet.GetExtendMinY, vImarisDataSet.GetExtendMinZ];
vDataMax = [vImarisDataSet.GetExtendMaxX, vImarisDataSet.GetExtendMaxY, vImarisDataSet.GetExtendMaxZ];
vDataSize = [vImarisDataSet.GetSizeX, vImarisDataSet.GetSizeY, vImarisDataSet.GetSizeZ];

Xvoxelspacing = (vDataMax(1)-vDataMin(1))/vDataSize(1);
Yvoxelspacing = (vDataMax(2)-vDataMin(2))/vDataSize(2);
Zvoxelspacing = (vDataMax(3)-vDataMin(3))/vDataSize(3);

% Choose surface list
vList = [];
% Surface selection list
[vList, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[350 200],'Name','Surface ID Mask','InitialValue',[1,1], ...
        'PromptString',{'Please select surfaces for exporting ID masks'});
if vOk == 0
    disp('No selection made.');
    return;
end    

if isempty(vList)
     uiwait(msgbox('No surface was chosen.'));
     return;
end

% Load selection of surfaces
vSelection = vSurfacesAll(vList, :);

% Check if the ID_Mask channel already exist for the surface
[a, b] = size(vSelection);
for vSel = 1:a
    surf_Names{vSel} = ['Index Mask ', char(vSelection{vSel, 3})];
end

for vCh = 1:vNumberOfChannels
    chan_Names{vCh} = char(vImarisDataSet.GetChannelName(vCh-1));
end

[diff_elements, iSurName] = setdiff(surf_Names, chan_Names);

vSurfSelection = vSelection(:, 4);
vSurfProcess = vSelection(iSurName, 4);
vSurfNameList = vSelection(iSurName, 3);

% Call function SurfaceIDMask 
vID_Mask = cell(1, length(vSurfProcess));  % Pre-allocate output cell array

% ==================== Call SurfaceIDMask Function =======================
for i = 1:numel(vSurfProcess)
    vID_Mask{i} = SurfaceIDMask(vSurfProcess{i}, vImarisApplication);
end
% ========================================================================

% The following MATLAB code returns the name of the dataset opened in 
% Imaris and saves file as IMS (Imaris5) format
vFileNameString = vImarisApplication.GetCurrentFileName; 
vFileName = char(vFileNameString);
[vOldFolder, vName, vExt] = fileparts(vFileName); 
vNewName   = [vName '_Idx_Mask.mat'];  
vNewFileName = fullfile(vOldFolder, vNewName); 
save(vNewFileName, 'vID_Mask');
vSurfNames = [vName '_Surface_List.mat'];
vNewListName = fullfile(vOldFolder, vSurfNames);
save(vNewListName, 'vSurfNameList');
end