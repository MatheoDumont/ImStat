# Kmeans
function length = l2(p1, p2)
  length = sum((p2 - p1).^2);
endfunction

function [clusters center] = kmeans(im, k, epsilon)
  center = [];
  for i = 1:k
    x = randi([1 size(im)(1)]);
    center = [center; im(x, :)];
  endfor
  
  #scatter(im(:, 1), im(:, 2), ".");
  #hold on;
  #axis equal;
  #scatter(center(:, 1), center(:, 2), 500, "d", "filled");

  # structure dans laquelle est stocke pour chaque point le cluster auquel il appartient
  clusters = zeros(size(im)(1), 1); 

  label_change = false;
  changement = true;

  while (changement)
    label_change = false;
    
    # on met a jour la position des centres des clusters
    # 1 on recupere les infos
    val = zeros(size(center));
    nb = ones(size(center), 1);
     
    # on met a jour l'appartenance des pts aux clusters existants
    for row = 1:size(im)(1)
      # on calcul le centre le plus proche
      idx_min_center = 1;
      d = l2(im(row, :), center(idx_min_center, :));
       
      for idx_center = 2:size(center)(1)
        current_d = l2(im(row, :), center(idx_center, :));
        
        if current_d < d
          d = current_d;
          idx_min_center = idx_center;
        endif
        
      endfor
      
      if clusters(row) != idx_min_center
        clusters(row) = idx_min_center;
        label_change = true;
      endif
      
      nb(clusters(row)) += 1;
      val(clusters(row), :) += im(row, :);
    endfor
     
    # keep track of the motion of center of cluster
    motion = center(:);
    
    # 2 on met a jour les centres a partir des infos
    for c = 1 : size(center)
      center(c, :) = val(c, :) / nb(c);
    endfor
    
    sum_motion = 0;
    for i = 1:size(center)(1)
      sum_motion += l2(motion(i, :), center(i, :));
    endfor
    sum_motion
    
    if  sum_motion < epsilon || !label_change
      changement = false;
    endif
    clf;
    scatter(im(:, 1), im(:, 2), [], clusters, ".");
    hold on;
    axis equal;
    scatter(center(:, 1), center(:, 2), 500, "d", "filled");

   
  endwhile
  
endfunction

# kmean algorithm
clear;
im = load("gmm2d.asc");
imshow(imr);
#im = reshape(imr, [size(imr)(1)*size(imr)(2), size(imr)(3)]);
k = 3;
epsilon = 1.0;
[clusters, centres] = kmeans(im, k, epsilon);



