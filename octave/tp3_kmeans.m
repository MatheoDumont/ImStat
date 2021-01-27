# Kmeans
function length = l2(p1, p2)
  length = sum((p2 - p1).^2);
endfunction

function [clusters center] = kmeans(im, k)
    center = [];
    # selection preliminaire aleatoire des centres 
    for i = 1:k
        x = randi([1 size(im)(1)]);
        center = [center; im(x, :)];
    endfor
    
    # structure dans laquelle est stocke pour chaque point le cluster auquel il appartient
    clusters = zeros(size(im)(1), 1); 

    label_change = true;
    changement = true;

    while (label_change)
        label_change = false;
        
        # pour calculer le centre des clusters ponderes par la positions de tous les points leurs appartenant
        val = zeros(size(center));
        nb = ones(size(center), 1);
         
        # on met a jour l'appartenance des pts aux clusters existants
        for row = 1:size(im)(1)
            # on calcul le centre le plus proche
            # pour chaque point
            idx_min_center = 1;
            d = l2(im(row, :), center(idx_min_center, :));
             
            for idx_center = 2:size(center)(1)
                current_d = l2(im(row, :), center(idx_center, :));
                
                if current_d < d
                    d = current_d;
                    idx_min_center = idx_center;
                endif
                
            endfor
            
            # signaler un changement
            if clusters(row) != idx_min_center
                clusters(row) = idx_min_center;
                label_change = true;
            endif
            
            nb(clusters(row)) += 1;
            val(clusters(row), :) += im(row, :);
        endfor
         
        
        # 2 on met a jour les centres a partir des infos
        for c = 1 : size(center)
            center(c, :) = val(c, :) / nb(c);
        endfor
        
      
        
    endwhile
endfunction

# kmean algorithm
clear;
im = load("data/classif/gmm2d.asc");
imshow(imr);
k = 3;
tic
[clusters, centres] = kmeans(im, k);
toc
clf;
scatter(im(:, 1), im(:, 2), [], clusters, ".");
hold on;
axis equal;
scatter(centres(:, 1), centres(:, 2), 500, "d", "filled");
waitforbuttonpress;
close all;


