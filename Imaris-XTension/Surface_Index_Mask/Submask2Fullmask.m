% Function: Submask2Fullmask, used with the Imaris XTension Surfce Index Mask
% Created by: En Cai, Department of Biological Sciences, Carnegie Mellon
% University, 2025/07.
% 
% This function is used in the function SurfaceIDMask. It maps submasks 
% back to the fullmask.
%

function fullLabeled = Submask2Fullmask(fullMask, subMask, SurfID, approxPositions, searchRadius)
% fullMask        : 3D logical array
% subMasks        : cell array of 3D submasks (values = 0 or objectID)
% approxPositions : [n x 3] matrix, each row = estimated [x, y, z] (1-based)
% searchRadius    : scalar (e.g., 2 or 3) — shift range in each dimension

[X, Y, Z] = size(fullMask);
fullLabeled = single(zeros(X, Y, Z));

sub = subMask;           % 3D submask

[sx, sy, sz] = size(sub);
est = approxPositions;  % estimated origin [x, y, z]

bestScore = -Inf;
bestPos = [];

% Try placing submask at various offsets within search window
for dx = -searchRadius:searchRadius
    for dy = -searchRadius:searchRadius
        for dz = -searchRadius:searchRadius
            %%
            x0 = est(1) + dx;
            y0 = est(2) + dy;
            z0 = est(3) + dz;
            % Compute valid crop ranges for fullMask
            x1 = max(1, x0);               x2 = min(X, x0 + sx - 1);
            y1 = max(1, y0);               y2 = min(Y, y0 + sy - 1);
            z1 = max(1, z0);               z2 = min(Z, z0 + sz - 1);

            % Corresponding submask indices
            sx1 = 1 + (x1 - x0);           sx2 = sx - (x0 + sx - 1 - x2);
            sy1 = 1 + (y1 - y0);           sy2 = sy - (y0 + sy - 1 - y2);
            sz1 = 1 + (z1 - z0);           sz2 = sz - (z0 + sz - 1 - z2);
            % Skip if the cropped region is too small
            if sx2 < sx1 || sy2 < sy1 || sz2 < sz1
                continue;
            end
            % Get subregion from full mask and submask
            fullCrop = fullMask(x1:x2, y1:y2, z1:z2);
            subCrop  = sub(sx1:sx2, sy1:sy2, sz1:sz2) > 0;
            % Compute overlap score (e.g., Dice or intersection)
            match = sum(fullCrop(:) & subCrop(:));
            union = sum(fullCrop(:) | subCrop(:));
            score = match / max(union, eps);  % IoU
            if score > bestScore
                bestScore = score;
                bestPos = [x1, y1, z1, sx1, sy1, sz1, sx2, sy2, sz2, x2, y2, z2];
            end
        end
    end
end

% Place best-matching crop into fullLabeled
if ~isempty(bestPos)
    x1 = bestPos(1); y1 = bestPos(2); z1 = bestPos(3);
    sx1 = bestPos(4); sy1 = bestPos(5); sz1 = bestPos(6);
    sx2 = bestPos(7); sy2 = bestPos(8); sz2 = bestPos(9);
    x2 = bestPos(10); y2 = bestPos(11); z2 = bestPos(12);

    subFinal = sub(sx1:sx2, sy1:sy2, sz1:sz2);
    region = fullLabeled(x1:x2, y1:y2, z1:z2);
    region(subFinal > 0) = 1;
    fullLabeled(x1:x2, y1:y2, z1:z2) = region;
else
    warning('Submask %d: No valid placement found. Skipped.', SurfID);
end
end