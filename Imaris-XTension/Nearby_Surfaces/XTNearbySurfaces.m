%
% Imaris XTension: Nearby Surfaces for Imaris 10
% Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
% University, 07/16/2025.
%
% This XTension creates two surface objects from the distance transformation
% channel with different thresholds, and creates masked channels in them.
%
% Dependencies:
% - Function: distantTransformationSubVolume.m
%
%  Installation:
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%<CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Nearby Surfaces" icon="Matlab">
%          <Command>MatlabXT::XTNearbySurfaces(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Nearby Surfaces" icon="Matlab">
%            <Command>MatlabXT::XTNearbySurfaces(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
%
%
function XTNearbySurfaces(aImarisApplicationID)
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

% Check for the selected surface
% The user has to create a scene with some surfaces
vSurpassScene = vImarisApplication.GetSurpassScene;

if isequal(vSurpassScene, [])
    msgbox('Please create some Surfaces in the Surpass scene!');
    return;
end

% Get all Surpass surfaces names
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

% If less than 2 surfaces found in the scene
if vNumberOfSurfaces<2
    msgbox('Please create at least 2 surfaces objects!');
    return;
end

% Get dataset and related info
vImarisDataSet = vImarisApplication.GetDataSet.Clone;
vNumberOfChannels = vImarisDataSet.GetSizeC;
aSizeT = vImarisApplication.GetDataSet.GetSizeT;

vDataMin = [vImarisDataSet.GetExtendMinX, vImarisDataSet.GetExtendMinY, vImarisDataSet.GetExtendMinZ];
vDataMax = [vImarisDataSet.GetExtendMaxX, vImarisDataSet.GetExtendMaxY, vImarisDataSet.GetExtendMaxZ];
vDataSize = [vImarisDataSet.GetSizeX, vImarisDataSet.GetSizeY, vImarisDataSet.GetSizeZ];

Xvoxelspacing = (vDataMax(1)-vDataMin(1))/vDataSize(1);
Yvoxelspacing = (vDataMax(2)-vDataMin(2))/vDataSize(2);
Zvoxelspacing = (vDataMax(3)-vDataMin(3))/vDataSize(3);

% Choose the surfaces to colocalize
vPrimarySurface=1;
vSecondarySurface=1;
vPrSurfSel = [];
vPair = [];
while vPrimarySurface==vSecondarySurface
    % Create Dialog box and allow user to choose the Reference Position
    vPrSurfSel = [];
    [vPrSurfSel, vOk] = listdlg('ListString',vNamesList,'SelectionMode','single',...
        'ListSize',[350 200],'Name','Near By Surface-Surface','InitialValue',1, ...
        'PromptString',{'Please select Primary Surface'});
    vPrimarySurface = vSurfacesList{vPrSurfSel(1)};
    % Create Dialog box and allow user to choose the Reference Position
    vPair = [];
    [vPair, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[350 200],'Name','Surface-Surface Contact Area','InitialValue',[1,1], ...
        'PromptString',{'Please select Secondary surface (one or more)'});
    vSecondarySurface = vSurfacesList{vPair(1)};
   
    if ~isempty(intersect(vPrSurfSel, vPair))
        uiwait(msgbox('Please choose different surfaces for primary and secondary surfaces.'));
    end
end
% Load selection of surfaces
vSelection = vSurfacesAll([vPrSurfSel, vPair], :);
vPrimarySurface = vSurfacesList{vPrSurfSel(1)};
vSurfSelection = vSelection(:, 4);
% Ask the user for the range of the neiborghhood
vAnswer = inputdlg({sprintf('Set the distance range (um)')},...
    ['Find nearby surfaces'], 1, {'0.3'});
if isempty(vAnswer), return, end
% Get the answer and save as the double
vDistRange = str2double(vAnswer{1});

% Check if the value is out of range
% Set range
warningBuffer = 3;
maxBuffer = min(vDataSize)/2;
% Stop the excution if range is more than half of the image size. Send
% warning when input value is larger than warningBuffer value. It is OK if
% input value < 0.
if vDistRange > maxBuffer
    fprintf('Error: The input is outof the range. Please try a smaller value.\n');
    return
elseif warningBuffer < vDistRange && vDistRange < maxBuffer
    choice = questdlg('Large input value. This will slowdown the calculation. Do you want to continue?', ...
        'Warning', ...
        'Yes', 'No', 'No');
    switch choice
        case 'Yes'
            disp('User chose to continue.');
        case 'No'
            disp('User chose to stop.');
            return;  % or use error('Stopping script.')
        otherwise
            disp('Dialog closed or canceled. Stopping.');
            return;
    end
end
% Get Sub Surface info
% Primary surface
vSurfPrimNum = vPrimarySurface.GetNumberOfSurfaces;

vStats = vPrimarySurface.GetStatistics;

% Center positions of subsurfaces
vPositionX = vPrimarySurface.GetStatisticsByName('Position X');
vPositionY = vPrimarySurface.GetStatisticsByName('Position Y');
vPositionZ = vPrimarySurface.GetStatisticsByName('Position Z');

vPosX = single(vPositionX.mValues);
vPosY = single(vPositionY.mValues);
vPosZ = single(vPositionZ.mValues);

vPosX_id = single(vPositionX.mIds);
vPosY_id = single(vPositionY.mIds);
vPosZ_id = single(vPositionZ.mIds);

mPosX = [vPosX_id, vPosX];
mPosY = [vPosY_id, vPosY];
mPosZ = [vPosZ_id, vPosZ];

% Bounding box in xyz of the subsurface
vBoundBoxX = vPrimarySurface.GetStatisticsByName('BoundingBoxAA Length X');
vBoundBoxY = vPrimarySurface.GetStatisticsByName('BoundingBoxAA Length Y');
vBoundBoxZ = vPrimarySurface.GetStatisticsByName('BoundingBoxAA Length Z');

vBbX = single(vBoundBoxX.mValues);
vBbY = single(vBoundBoxY.mValues);
vBbZ = single(vBoundBoxZ.mValues);

vBbX_id = single(vBoundBoxX.mIds);
vBbY_id = single(vBoundBoxY.mIds);
vBbZ_id = single(vBoundBoxZ.mIds);

mBbX = [vBbX_id, vBbX];
mBbY = [vBbY_id, vBbY];
mBbZ = [vBbZ_id, vBbZ];

% Time index for each subsurface
vTimeSurf = vPrimarySurface.GetStatisticsByName('Time');
vTSurf = single(vTimeSurf.mValues);
vT_id = single(vTimeSurf.mIds);

mT = [vT_id, vTSurf];

% Voxel info for all selected surfaces
vVoxel_pSurf = vPrimarySurface.GetStatisticsByName('Number of Voxels');
vVoxSurf = single(vVoxel_pSurf.mValues);
vVox_id = single(vVoxel_pSurf.mIds);
mVoxSurf = [vVox_id, vVoxSurf];

% Store into cell array
cSurfInfo = {mPosX; mPosY; mPosZ; mBbX; mBbY; mBbZ; mT; mVoxSurf};

% Make this into a Matrix with Surfce ID algined
all_ids = sort(cSurfInfo{1}(:,1));     % reference ID list
n = numel(all_ids);
num_cols = size(cSurfInfo,1);
result = NaN(n, num_cols);

for i = 1:num_cols
    ids = cSurfInfo{i}(:,1);
    vals = cSurfInfo{i}(:,2);
    [~, idx] = ismember(all_ids, ids);
    result(:,i) = vals(idx);
end

% If ID == 0, set it to 0.1
all_ids(all_ids == 0) = 0.1;

mSurfInfo = [all_ids, result];

% % mSurfInfo Columns ================
% Column 1: ID
% Column 2: Position X
% Column 3: Position Y
% Column 4: Position Z
% Column 5: BbX
% Column 6: BbY
% Column 7: BbZ
% Column 8: Time
% Column 9: Number of Voxels
% % ==================================

% Voxel index of the center of surfaces 
vPosX_vox = round((mSurfInfo(:,2)-vDataMin(1))/Xvoxelspacing)+1;
vPosY_vox = round((mSurfInfo(:,3)-vDataMin(2))/Yvoxelspacing)+1;
vPosZ_vox = round((mSurfInfo(:,4)-vDataMin(3))/Zvoxelspacing)+1;

% Make a buffer with size 5 times of vDistRange
%   Set limit on the bounding box size
minBuffer = 0.5;

if vDistRange < 0.1
    BufSize = 0.1;
else
    BufSize = vDistRange;
    BufSizeZ = BufSize*(Zvoxelspacing/Xvoxelspacing);
end


% Find the boundary of the subsurface(with padding in each side).
vBdrX_min0 = mSurfInfo(:,2) - (mSurfInfo(:,5)/2 + BufSize);
vBdrX_max0 = mSurfInfo(:,2) + (mSurfInfo(:,5)/2 + BufSize);
vBdrY_min0 = mSurfInfo(:,3) - (mSurfInfo(:,6)/2 + BufSize);
vBdrY_max0 = mSurfInfo(:,3) + (mSurfInfo(:,6)/2 + BufSize);
vBdrZ_min0 = mSurfInfo(:,4) - (mSurfInfo(:,7)/2 + BufSizeZ);
vBdrZ_max0 = mSurfInfo(:,4) + (mSurfInfo(:,7)/2 + BufSizeZ);

% Set the mask boundary
vBdrX_min = max(vBdrX_min0, vDataMin(1));
vBdrX_max = min(vBdrX_max0, vDataMax(1));
vBdrY_min = max(vBdrY_min0, vDataMin(2));
vBdrY_max = min(vBdrY_max0, vDataMax(2));
vBdrZ_min = max(vBdrZ_min0, vDataMin(3));
vBdrZ_max = min(vBdrZ_max0, vDataMax(3));

% Calculate voxel index of first voxel (upleft corner of bounding boxes)
vSubMask_X0 = round((vBdrX_min-vDataMin(1))/Xvoxelspacing)+1;
vSubMask_Y0 = round((vBdrY_min-vDataMin(2))/Yvoxelspacing)+1;
vSubMask_Z0 = round((vBdrZ_min-vDataMin(3))/Zvoxelspacing)+1;

% Calculate number of voxels
vSubSurfSizeX = round((vBdrX_max - vBdrX_min)/Xvoxelspacing);
vSubSurfSizeY = round((vBdrY_max - vBdrY_min)/Yvoxelspacing);
vSubSurfSizeZ = round((vBdrZ_max - vBdrZ_min)/Zvoxelspacing);

% Calculate voxel index of last voxel (lower-right corner of bounding
% boxes)
vSubMask_X1 = vSubMask_X0 + vSubSurfSizeX -1;
vSubMask_Y1 = vSubMask_Y0 + vSubSurfSizeY -1;
vSubMask_Z1 = vSubMask_Z0 + vSubSurfSizeZ -1;


vNofVox = mSurfInfo(:,9);
clear vBdrX_min0 vBdrX_max0 vBdrY_min0 vBdrY_max0 vBdrZ_max0 vBdrZ_min0

if length(vSurfSelection) < 2
    disp('Less than 2 surfaces!')
    return;
end

vIds = {};
vIds{1} = all_ids;
cVoxSurf_s = {};
cVoxSurf_s{1} = mVoxSurf;

for i=2:length(vSurfSelection)
    vIds{i} = vSurfSelection{i}.GetIds;
    vScdSurf = vSurfSelection{i};
    vScdStats = vScdSurf.GetStatistics;
    % Voxel info for all secondary surfaces
    vVoxel_sSurf = vScdSurf.GetStatisticsByName('Number of Voxels');
    vVoxSurf_s = single(vVoxel_sSurf.mValues);
    vVox_id_s = single(vVoxel_sSurf.mIds);
    vVox_id_s(vVox_id_s == 0) = 0.1;
    cVoxSurf_s{i} = [vVox_id_s, vVoxSurf_s];
    clear vScdSurf vScdStats vVoxel_sSurf vVoxSurf_s vVox_id_s
end

% Get channel names
vChannelNamelist = {};
for vCh = 1: vNumberOfChannels
    vChannelNamelist{vCh} = vImarisDataSet.GetChannelName(vCh-1);
    vChannelColor{vCh} = vImarisDataSet.GetChannelColorRGBA(vCh-1);
end


% Convert channel names to char arrays
vChannelNamelistChar = cellfun(@char, vChannelNamelist, 'UniformOutput', false);

for i=1:length(vSurfSelection)
    % Get channel Ids for secondary surfaces: channel names contain "ID
    % Mask" + surface name, if multiple, use first one
    sName = vSurfSelection{i}.GetName;
    % sName is a string with the surface name
    targetPattern = ['Index Mask ', regexptranslate('escape', char(sName)), '$'];
    % Match full channel name using case-insensitive regex
    containsExact = cellfun(@(s) ~isempty(regexpi(s, targetPattern)), vChannelNamelistChar);
    % Find matching channel index
    if isempty(find(containsExact))
        disp('No Index Mask Channels for selected surfaces.')
        return;
    else
        vChannelIdxtoMask(i) = find(containsExact, 1, 'first');
    end
end

vDataSet = vImarisApplication.GetDataSet.Clone;
vDataSet.Resize(0, int32(max(vSubSurfSizeX)+1),...
    0, int32(max(vSubSurfSizeY)+1), ...
    0, int32(max(vSubSurfSizeZ)+1), 0, 2, 0, 1);

for vTime = 1:aSizeT
    
    % Load Id mask for all selected surfaces
    vIdMasks = {};
    for i=1:length(vSurfSelection)
        % Find matching channel index
        if isempty(vChannelIdxtoMask(i))
            vIdMasks{i} = [];
        else
            vIdMasks{i} = vImarisDataSet.GetDataVolumeFloats(int32(vChannelIdxtoMask(i)-1), int32(vTime-1));
        end
    end
    
    % Find Idx of sub-surfaces at t=vTime-1
    SurfIdx_t = find(mSurfInfo(:,8) == vTime-1);
    nearbySurf2 = {};
    
    for vSurfIdx0 = 1:length(SurfIdx_t)
        
        vSurfIdx0
        vSurfIdx = SurfIdx_t(vSurfIdx0);
        
        vSingleMask = vPrimarySurface.GetSingleMask(vSurfIdx-1, ...
            vBdrX_min(vSurfIdx), vBdrY_min(vSurfIdx), vBdrZ_min(vSurfIdx), ...
            vBdrX_max(vSurfIdx), vBdrY_max(vSurfIdx), vBdrZ_max(vSurfIdx), ...
            int32(vSubSurfSizeX(vSurfIdx)), int32(vSubSurfSizeY(vSurfIdx)), ...
            int32(vSubSurfSizeZ(vSurfIdx)));
        
        % Generate Sub Mask of 0 and 1*vSurfIdx
        vSubMask = single(vSingleMask.GetDataVolumeBytes(0, vTime-1));
        
        % Only process SubSurfaces with voxel > 4
                if nnz(vSubMask) < 5
                    continue;
                end
        
        sizeX = int32(vSubSurfSizeX(vSurfIdx));
        sizeY = int32(vSubSurfSizeY(vSurfIdx));
        sizeZ = int32(vSubSurfSizeZ(vSurfIdx));
        % -------------------SubVolume DT----------------------------------
        % Call Function: distantTransformationSubVolume
        distTranAll = distantTransformationSubVolume(vImarisApplication, vDataSet, vSubMask, sizeX, sizeY, sizeZ, Xvoxelspacing, Yvoxelspacing, Zvoxelspacing);
        
        % Get ID Masks for the subVolume
        nearbySurf1 = {};
        % Mask Secondary Surface 1 (vID_Mask)
        for vSecSurf_n = 2: length(vSurfSelection) % skip the first surface (primary surf)
            vIdMask1 = vIdMasks{vSecSurf_n};
            vIdMask1_sub = vIdMask1(vSubMask_X0(vSurfIdx):vSubMask_X1(vSurfIdx),...
                vSubMask_Y0(vSurfIdx):vSubMask_Y1(vSurfIdx),...
                vSubMask_Z0(vSurfIdx):vSubMask_Z1(vSurfIdx));
            nonzero_elements = vIdMask1_sub(vIdMask1_sub ~= 0);
            surfID = unique(nonzero_elements(:));
            mVoxSurf_s = cVoxSurf_s{vSecSurf_n};
            
            nearbySurf0 = [];
            vIds_s = vIds{vSecSurf_n};
            if isempty(surfID)
                nearbySurf0(1, 1) = all_ids(vSurfIdx);   % Primary subSurface ID
                nearbySurf0(1, 2) = vNofVox(vSurfIdx);   % Primary subSurface Voxel number
                nearbySurf0(1, 3) = 0; % Secondary subSurface ID
                nearbySurf0(1, 4) = 0; % Secondary subSurface Voxel number
                nearbySurf0(1, 5) = 0; % min DT
                nearbySurf0(1, 6) = vTime;  % Time
            else
                for idx = 1:length(surfID)
                    nearbySurf0(idx, 1) = all_ids(vSurfIdx);   % Primary subSurface ID
                    nearbySurf0(idx, 2) = vNofVox(vSurfIdx);   % Primary subSurface Voxel number
                    nearbySurf0(idx, 3) = surfID(idx); % Secondary subSurface ID
                    midx = find(mVoxSurf_s(:,1)==surfID(idx));
                    nearbySurf0(idx, 4) =  mVoxSurf_s(midx,2); % Secondary subSurface Voxel number
                    nearbySurf0(idx, 5) = min(distTranAll(find(vIdMask1_sub == surfID(idx)))); % min DT
                    nearbySurf0(idx, 6) = vTime;  % Time
                end
            end
            nearbySurf{vSurfIdx0, vSecSurf_n-1, vTime} = nearbySurf0;
        end
    end
end

% Get folder to save
vFileNameString = vImarisApplication.GetCurrentFileName; 
vFileName = char(vFileNameString);
[vOldFolder, vName, vExt] = fileparts(vFileName); 
vNewFolder = fullfile(vOldFolder, 'coloc_result');   
if ~exist(vNewFolder, 'dir')
    mkdir(vNewFolder);
end
Pf_name = char(vPrimarySurface.GetName);
PrmSurf_name = strtok(Pf_name);
% Save as Table
col = size(nearbySurf{1,1}, 2); % Get number of columns
n1 = size(nearbySurf, 1); % Get n of surfaces
n2 = size(nearbySurf, 2);  % Get n of sheet
nt = size(nearbySurf, 3); % Get n of t

cResult = cell(1, n2);         % initialize output cell array

for j = 1:n2
    cResult{j} = cell(n2, 1);  % preallocate column cell for j-th element
   
    for i = 1:n1
        if isempty(nearbySurf{i, j})
            cResult{j}{i} = zeros(1, 6);
        else
            cResult{j}{i} = nearbySurf{i, j};  % collect the j-th element from each inner cell
        end
    end
    % convert to matrix if contents are numeric
    if isnumeric(cResult{j}{1})
        cResult{j} = cat(1, cResult{j}{:});
    end
    
    % Save as CSV with col: [Main Surf, Main Surf Voxel number, Secondary Surf, Secondary Surf Voxels, Min DT, Time]
    Surf1 = cResult{j}(:,1);
    Surf1_Vox = cResult{j}(:,2);
    Surf2 = cResult{j}(:,3);
    Surf2_Vox = cResult{j}(:,4);
    DT_min = cResult{j}(:,5);
    Time = cResult{j}(:,6);
    
    T = table(Surf1, Surf1_Vox, Surf2, Surf2_Vox, DT_min, Time);
    Sf_name = char(vSurfSelection{j+1}.GetName);
    ScdSurf_name = strtok(Sf_name);
    vNewName = [vName '_' PrmSurf_name '_' ScdSurf_name '_NearBySurfaces.csv'];
    vNewFileName = fullfile(vNewFolder, vNewName); 
    writetable(T, vNewFileName);
end

end





