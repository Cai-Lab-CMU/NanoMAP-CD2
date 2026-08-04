% Function: align2Fullmask, used with the Imaris XTension Surfce Index Mask
% Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
% University, 2025/07.
% 
% This function is used in the function SurfaceIDMask. It aligns submasks 
% that are mapped to the fullmask to reduce the mismatch.
%

function vMask0 = align2Fullmask(vFullMask, vMask_raw)
% Set overflow voxels in vMask_raw to zero
vMask0 = vMask_raw.*vFullMask;

% Find missing pixels in vMask_raw comapred to vFullMask
sz = size(vFullMask);
n1 = find(vFullMask);
n2 = find(vMask0);

[x1, y1, z1] = ind2sub(sz, n1);
coord1 =[x1(:), y1(:), z1(:)];
[x2, y2, z2] = ind2sub(sz, n2);
coord2 =[x2(:), y2(:), z2(:)];

missingVoxels = setdiff(coord1, coord2, "rows"); % Voxels in vFullMask, but not in vMask_raw

% Find nearst surface for missing Voxels
% Label Volume: get the index to nearest foreground voxel
[~, idxMap] = bwdist(vMask0);
% Get the missing voxel positions
mV_x = missingVoxels(:,1);
mV_y = missingVoxels(:,2);
mV_z = missingVoxels(:,3);
% Convert to linear index
mV_Idx = sub2ind(sz, mV_x, mV_y, mV_z);
% Nearest foreground voxel index
mV_nearestIdx = idxMap(mV_Idx);
%
if ~isempty(missingVoxels)
    % Fill in the voxels
    for mVid = 1:length(missingVoxels)
        %              % Get the cluster IDs in labelMask for the missing voxels --> they are not currently included in any of the surfaces
        %              clusterID(mVid) = labelMask(mV_x(mVid), mV_y(mVid), mV_z(mVid));
        % Find out which surface this voxel belongs to
        [xm, ym, zm] = ind2sub(sz ,mV_nearestIdx(mVid));
        % Label this voxel with the correct surface ID
        vMask0(mV_x(mVid), mV_y(mVid), mV_z(mVid)) = vMask0(xm, ym, zm);
    end
end
end