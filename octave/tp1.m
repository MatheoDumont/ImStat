
function distance = SSD(I, Ismp, posI, posIsmp, taille_filtre)
  n = floor(taille_filtre/2);
  distance = 0;
  for row = -n:n
    for col = -n:n
      
      v_I = I(posI(1)+row, posI(2)+col, :);
      v_Ismp = Ismp(posIsmp(1)+row, posIsmp(2)+col, :);
      if (v_Ismp == 0)
        continue;
      endif
      distance += pow2(v_I - v_Ismp);
    endfor
  endfor
endfunction

function under = best_patch(im, I, max_pix, window_size, epsilon)
  n = floor(window_size/2);
  position_best = [1, 1];
  val_best = 10000;
  
  positions = [];
  val_p = [];
  for row = 2:size(im)-1
    for col = 2:size(im)-1
      
      #d = SSD(im, I, [row, col], max_pix, window_size);
     
      A = im((-n:n) + row, (-n:n) + col, :);
      B = I((-n:n) + max_pix(1), (-n:n) + max_pix(2), :);
      
      mask_b = sum(B,3);
      mask_b = max(1, mask_b);
      A = A.* (1 - mask_b);
      
      d = (A - B).^2; 
      d = sum(d(:, :, :));
       
      positions = [positions ;[row, col]];
      val_p = [val_p ; d];
      
      if (d < val_best)
        
        position_best = [row, col];
        val_best = d;
      endif
      
    endfor
  endfor
  
  under = [];
  for i = 1:size(positions)
    if(val_p(i) <= val_best * (1+epsilon))
      under = [under; positions(i, :)];
    endif
  endfor

endfunction 

function idx = argmax2(I)
  idx = [1,1];
  val = I(1, 1);
  for x = 2:size(I)(1)
    for y = 2:size(I)(2)
      if (I(x, y) > val)
        val = I(x, y);
        idx = [x,y];
      endif
    endfor
  endfor
endfunction

function max_pix =  pick_pixel(I, n)
  f  = ones(n,n, "uint");
  f(int8(n/2),int8(n/2)) = 0;

  i = uint8(logical(I(:,:,1))) + uint8(logical(I(:,:,2)))+ uint8(logical(I(:,:,3)));
  i = min(i,1);
  r = conv2(i, f, "same");
  r = r .* (1 - i);
  
  max_pix = argmax2(r);
endfunction


im = imread("data/text0.png");
imshow(im);
I = zeros(size(im), "uint8");
l = 1
epsilon = 2.5;
window_size = l*3
center = size(I)(1) / 2;
I(center-l:center+l, center-l:center+l,:) = im(center-l:center+l, center-l:center+l,:);
empty = size(im)(1)*size(im)(1) - window_size*window_size;

em = empty;
em -= 250;

while(empty != em)
  # pick the pixel with the his neighboorhood filled the most
  f  = ones(window_size,window_size, "uint");
  f(int8(window_size/2),int8(window_size/2)) = 0;

  i = uint8(sum(I, 3));
  i = min(i,1);
  r = conv2(i, f, "same");
  r = r .* (1 - i);
  
  max_pix = argmax2(r);
  
  # meilleur patch
  patch_under_esp = best_patch(im, I, max_pix, window_size, epsilon);
  
  
  randomIndex = randi(length(patch_under_esp), 1);
  p = patch_under_esp(randomIndex, :);
  
  I(max_pix(1), max_pix(2), :) = im(p(1), p(2), :);
  empty -= 1;
endwhile

imshow(I); 


l = [];
l = [l; [1,2]];