# ouvrir images
# prendre pixel
# calculer homography
# utiliser vgg_warp
# decrire les artefacts


# calculer homography
# https://medium.com/all-things-about-robotics-and-computer-vision/homography-and-how-to-calculate-it-8abf3a13ddc5
function [H] = homography(matched_pixel)
  M = [];
  for i=1:size(matched_pixel)
    x = matched_pixel(i, 1);
    y = matched_pixel(i, 2);
    xp = matched_pixel(i, 3);
    yp = matched_pixel(i, 4);
    v = [x y 1 0 0 0 -(xp*x) -(xp*y) -xp];
    M = [M; v];
    v = [0 0 0 x y 1 -(yp*x) -(yp*y) -yp];
    M = [M; v];
  endfor
  [U S V] = svd(M);
  
  H = V(:,end);
  H = reshape(H,3,3);
  H = H';
endfunction

function create_panorama(A, B, H)
  # code de `vgg_warp_H')
  [m, n, l] = size(A);
  y = H*[[1;1;1], [1;m;1], [n;m;1] [n;1;1]];
  y(1,:) = y(1,:)./y(3,:);
  y(2,:) = y(2,:)./y(3,:);
  bbox = [
          ceil(min(y(1,:)));
          ceil(max(y(1,:)));
          ceil(min(y(2,:)));
          ceil(max(y(2,:)));
  ];
  bbox(2) = bbox(2) + size(B, 2) / 2;
  bbox = transpose(bbox);

  Ap = vgg_warp_H(A, H, "nearest", bbox);
  Bp = vgg_warp_H(B, eye(3), "nearest", bbox);
  f = max(Ap, Bp);

  subplot(1, 3, 1); 
  imshow(A); 
  
  subplot(2, 3, 2); 
  imshow(f); 
  title("Panorama");
  
  subplot(1, 3, 3); 
  imshow(B); 
  
  waitforbuttonpress;
  close all;
endfunction

# EXERCICE 1
# ouvrir images
A = imread("data/regression/keble_a.jpg");
B = imread("data/regression/keble_b.jpg");

# prendre pixels
matched_pixel = [658 287 366 289; 642 360 347 361; 681 359 386 361; 342 56 50 39];
H = homography(matched_pixel);
  
# utiliser vgg_warp
im_warped = vgg_warp_H(A, H);
#im_warped = vgg_warp_H(B, inverse(H));
im_warped = (im_warped/2 + B) ;
subplot(131);
imshow(A);
subplot(132);
imshow(im_warped);
subplot(133);
imshow(B);

# construire de plus grandes images
#NI = vgg_warp_H(A,H, 'linear', 'fit');
#res =  zeros(size(NI, 1), size(NI, 2) * 2, 3, "uint8");
#res(:, 1:size(NI, 2), :) = NI;
#res(:, size(NI, 2):size(B, 2), :) = B;
#imshow(res);
# ca marche pas bien ... il faudrait joindre les deux bords, surement un algo comme ceux de synthetisation d'image

# EXERCICE 2

function [distance, choosen] = RANSAC(listofpair, A, B)
  distance = 100000000;
  choosen = [];
  
  # parametre : nombre d'iteration
  n_iter = 10;
  # parametre : nombre de pair selectionnees par iteration
  n = 4;
  
  for i=1:n_iter
    pick = [];
    # pick n pair of points
    for j=1:n
      row = (size(listofpair)-1) * rand + 1;
      row = int32(row);
      pick = [pick; listofpair(row, :)];
    endfor
    h = homography(pick);
    warpped = vgg_warp_H(A, h);
    
    cur_dis = 0;
    # compute error / distance
    for j=1:n
      pos_pix_B = [pick(j, 3), pick(j, 4)];
      
      pix_A = warpped(int32(pos_pix_B));
      pix_B = B(int32(pos_pix_B));
 
      cur_dis += dot(pix_B - pix_A, pix_B - pix_A);
    endfor
    
    if (cur_dis < distance)
      distance = cur_dis;
      choosen = pick;
    endif
    
  endfor
  
endfunction

pairofpoints = importdata("data/regression/matchesab.txt");
A = imread("data/regression/keble_a.jpg");
B = imread("data/regression/keble_b.jpg");

[d worthy] = RANSAC(pairofpoints, A, B);
H = homography(worthy);
im_warped = vgg_warp_H(A, H);
#im_warped = vgg_warp_H(B, inverse(H));
subplot(231);
imshow(A);
subplot(232);
imshow(im_warped);
subplot(233);
imshow(B);

create_panorama(A,B,H);


# Resultat exo 1 pour comparer (a afficher avec)
subplot(235);
matched_pixel = [658 287 366 289; 642 360 347 361; 681 359 386 361; 342 56 50 39];
h = homography(matched_pixel);
im_warped = vgg_warp_H(A, h);
imshow(im_warped);

# on test 10 fois pour voir a quel point les resultats peuvent varier
for i=1:10
  [d worthy] = RANSAC(pairofpoints, A, B);
  H = homography(worthy);
  im_warped = vgg_warp_H(A, H);
  im_warped = (im_warped/2 + B);
  #im_warped = vgg_warp_H(B, inverse(H));
  
  subplot(2, 5, i);
  imshow(im_warped);
  
endfor


# avec panorama


# Exercice 2 avec seuil

function [distance, choosen] = RANSAC_threshold(listofpair, A, B)
  distance = 100000000;
  choosen = [];
  threshold = 200.0;
  
  # parametre : nombre de pair selectionnees par iteration
  n = 4;
  
  while distance > threshold
    pick = [];
    # pick n pair of points
    for j=1:n
      row = (size(listofpair)-1) * rand + 1;
      row = int32(row);
      pick = [pick; listofpair(row, :)];
    endfor
    h = homography(pick);
    warpped = vgg_warp_H(A, h);
    
    cur_dis = 0;
    # compute error / distance
    for j=1:n
      pos_pix_B = [pick(j, 3), pick(j, 4)];
      
      pix_A = warpped(int32(pos_pix_B));
      pix_B = B(int32(pos_pix_B));
 
      cur_dis += dot(pix_B - pix_A, pix_B - pix_A);
    endfor
    
    if (cur_dis < distance)
      distance = cur_dis;
      choosen = pick;
    endif
  endwhile
  
endfunction

for i=1:10
  [d worthy] = RANSAC_threshold(pairofpoints, A, B);
  H = homography(worthy);
  #im_warped = vgg_warp_H(A, H);
  #im_warped = (im_warped/2 + B);
  #im_warped = vgg_warp_H(B, inverse(H));
  create_panorama(A,B,H);
  #subplot(2, 5, i);
  #imshow(im_warped);
  
endfor
create_panorama(A,B,H);
