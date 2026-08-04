% Function: SurfaceIDMask, used with the Imaris XTension Surfce Index Mask
% Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
% University, 2025/07.
%
% This function processes a list of Surfaces from the given Imaris Application
% file and create a mask from the surface with subsurface index.
% Inputs:
%      vSurfaceList: cell array of Imaris surfaces
%      vImarisApplications: a given Imaris application
% Outputs:
%      Creates a channel of ID Mask for each surface object.
%      Save the cell array of vID_Mask to the data folder.
% Dependencies:
% - Function: Submask2Fullmask.m
% - Function: align2Fullmask.m
% 
% Note: to speed the process, use bounding boxes to reduce datasize

function vMask = SurfaceIDMask(vSurface, vImarisApplication)

% ===========Set parameters=================
buffer = 5;
searchRadius = 1;
% ==========================================
% Get dataset and info
vImarisDataSet = vImarisApplication.GetDataSet.Clone;
vNumberOfChannels = vImarisDataSet.GetSizeC;
aSizeT = vImarisApplication.GetDataSet.GetSizeT;

vDataMin = [vImarisDataSet.GetExtendMinX, vImarisDataSet.GetExtendMinY, vImarisDataSet.GetExtendMinZ];
vDataMax = [vImarisDataSet.GetExtendMaxX, vImarisDataSet.GetExtendMaxY, vImarisDataSet.GetExtendMaxZ];
vDataSize =[vImarisDataSet.GetSizeX, vImarisDataSet.GetSizeY, vImarisDataSet.GetSizeZ];

Xvoxelspacing = (vDataMax(1)-vDataMin(1))/vDataSize(1);
Yvoxelspacing = (vDataMax(2)-vDataMin(2))/vDataSize(2);
Zvoxelspacing = (vDataMax(3)-vDataMin(3))/vDataSize(3);

% Get surface info for input vSurface
vNumberOfSurfaces = vSurface.GetNumberOfSurfaces;
vSurfacesIDs = vSurface.GetIds;
vSurfacesIdx = [1:vNumberOfSurfaces]';

% Get subsurface stats
vStats = vSurface.GetStatistics;

% Center positions of subsurfaces
vPositionX = vSurface.GetStatisticsByName('Position X');
vPositionY = vSurface.GetStatisticsByName('Position Y');
vPositionZ = vSurface.GetStatisticsByName('Position Z');

vPosX = single(vPositionX.mValues); % Check and make sure vPosX is a column vector.
vPosY = single(vPositionY.mValues);
vPosZ = single(vPositionZ.mValues);

vPosX_id = single(vPositionX.mIds);
vPosY_id = single(vPositionY.mIds);
vPosZ_id = single(vPositionZ.mIds);

mPosX = [vPosX_id, vPosX];
mPosY = [vPosY_id, vPosY];
mPosZ = [vPosZ_id, vPosZ];

% Bounding box in xyz of the subsurface
vBoundBoxX = vSurface.GetStatisticsByName('BoundingBoxAA Length X');
vBoundBoxY = vSurface.GetStatisticsByName('BoundingBoxAA Length Y');
vBoundBoxZ = vSurface.GetStatisticsByName('BoundingBoxAA Length Z');

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
vTimeSurf = vSurface.GetStatisticsByName('Time');
vTSurf = single(vTimeSurf.mValues);
vT_id = single(vTimeSurf.mIds);

mT = [vT_id, vTSurf];

% Store into cell array
cSurfInfo = {mPosX; mPosY; mPosZ; mBbX; mBbY; mBbZ; mT};

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
% % ==================================

% Find the boundary of the subsurface(with 5 Voxel padding on each side).
BufSize = buffer*Xvoxelspacing;
BufSizeZ = buffer*Zvoxelspacing;
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

% Calculate voxel index of upleft corner of bounding boxes
vSubMask_X0 = round((vBdrX_min-vDataMin(1))/Xvoxelspacing)+1;
vSubMask_Y0 = round((vBdrY_min-vDataMin(2))/Yvoxelspacing)+1;
vSubMask_Z0 = round((vBdrZ_min-vDataMin(3))/Zvoxelspacing)+1;

% Calculate number of voxels
vSubSurfSizeX = round((vBdrX_max - vBdrX_min)/Xvoxelspacing);
vSubSurfSizeY = round((vBdrY_max - vBdrY_min)/Yvoxelspacing);
vSubSurfSizeZ = round((vBdrZ_max - vBdrZ_min)/Zvoxelspacing);

clear vBdrX_min0 vBdrX_max0 vBdrY_min0 vBdrY_max0 vBdrZ_max0 vBdrZ_min0

% Create a new channel in Imaris
vImarisDataSet.SetSizeC(vNumberOfChannels + 1);
vImarisDataSet.SetChannelName(vNumberOfChannels,['Index Mask ', char(vSurface.GetName)]);
vImarisDataSet.SetChannelColorRGBA(vNumberOfChannels, 255*256*256);

% Set the voxel range to search and fit the FullMask
BoxPositions = [vSubMask_X0, vSubMask_Y0, vSubMask_Z0];

% Label mask with ID info for individual subsurface
vMask = {};
for vTime = 1:aSizeT
    % Get the FullMask for comparison
    vFullMask0 = vSurface.GetMask(vDataMin(1), vDataMin(2), vDataMin(3),...
        vDataMax(1), vDataMax(2), vDataMax(3), ...
        int32(vDataSize(1)), int32(vDataSize(2)), int32(vDataSize(3)), vTime-1);
    vFullMask = single(vFullMask0.GetDataVolumeBytes(0, vTime-1));
    
    vMask0 = single(zeros(vDataSize(1), vDataSize(2), vDataSize(3)));
    vMask_raw = single(zeros(vDataSize(1), vDataSize(2), vDataSize(3)));
    % Find Idx of sub-surfaces at t=vTime-1
    SurfIdx_t = find(mSurfInfo(:,8) == vTime-1);
   
    for vSurfIdx0 = 1:length(SurfIdx_t)
        %vSurfIdx0
        vSurfIdx = SurfIdx_t(vSurfIdx0);
       
        % Get Single Mask of this surface
        vSingleMask = vSurface.GetSingleMask(vSurfIdx-1, ...
            vBdrX_min(vSurfIdx), vBdrY_min(vSurfIdx), vBdrZ_min(vSurfIdx), ...
            vBdrX_max(vSurfIdx), vBdrY_max(vSurfIdx), vBdrZ_max(vSurfIdx), ...
            int32(vSubSurfSizeX(vSurfIdx)), int32(vSubSurfSizeY(vSurfIdx)), ...
            int32(vSubSurfSizeZ(vSurfIdx)));
        
        % Generate Sub Mask of 0 and 1*vSurfIdx
        vSubMask = vSingleMask.GetDataVolumeBytes(0, vTime-1);
       
        % -------------Fit SubMask into FullMask----------------------
        approxPositions = BoxPositions(vSurfIdx,:);
        
        fullLabeled = Submask2Fullmask(vFullMask, vSubMask, vSurfIdx, approxPositions, searchRadius);
        % Pass non-zero values from fullLabeled to vMask0
        mask = fullLabeled ~= 0;
        vMask_raw(mask) = all_ids(vSurfIdx) * cast(fullLabeled(mask), class(vMask_raw));
        clear vMask_raw0 mask fullLabeled vSingleMask vSubMask
        
    end
    % Fully align with vFullMask
    vMask0 = align2Fullmask(vFullMask, vMask_raw);
    vMask{vTime} = vMask0;
    % Save the Idex Mask in the new channel
    if strcmp(vImarisDataSet.GetType,'eTypeUInt8')
        vImarisDataSet.SetDataVolumeBytes(uint8(vMask0), vNumberOfChannels, vTime-1);
    elseif strcmp(vImarisDataSet.GetType,'eTypeUInt16')
        vImarisDataSet.SetDataVolumeShorts(uint16(vMask0), vNumberOfChannels, vTime-1);
    elseif strcmp(vImarisDataSet.GetType,'eTypeFloat')
        vImarisDataSet.SetDataVolumeFloats(single(vMask0), vNumberOfChannels, vTime-1);
    end
    vImarisApplication.SetDataSet(vImarisDataSet);
    clear vMask0 vSingleMask vSubMask 
   
end

end

