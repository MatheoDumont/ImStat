function y = f_mu_sigma(x, mu, sigma, pi)
  xu = (x - mu);
  e = exp(-1/2 * xu * inverse(sigma) * transpose(xu));
  d = length(size(sigma));
  y = (1 / (power(2*pi, 1/d) * sqrt(det(sigma)))) * e;
endfunction

function Qij = EM(data, k)
    n = size(data,1);
    # init
    pis = zeros(1, k);
    dim = length(size(data));
    sigmas = cell(1, k);
    mus = zeros(k, dim);

    pi_init = 1.0/k;
    sig_init = cov(data);

    for i=1:k
        pis(i) = pi_init;
        sigmas{i} = sig_init;
        idx = (n - 1) * rand + 1;
        mus(i, :) = data(int32(idx), :);   
    endfor
    
    Qij = zeros(n, k);
    
    for iteration = 1:10
        # pour expect
        sum_Qij = zeros(1, k);
        sum_data = zeros(1, size(data, 2));
        
        # Expectation
        for i = 1:n
            d = data(i,:);
            sum_data += d;
            for j = 1:k
                Qij(i,j)= pis(j) * f_mu_sigma(d, mus(j, :), sigmas{j}, pis(j));
            endfor
            s = sum(Qij(i, :));
            Qij(i, :) = Qij(i, :) / s;
            sum_Qij += Qij(i, :);
        endfor
        
        # Maximization`
        # pi
        pis = sum_Qij / n;
        
        # Mu
        for j = 1:k
            mus(j, :) = (sum_data * sum_Qij(j)) / sum_Qij(j);
        endfor
        
        # sigma
        for j = 1:k
            somme = zeros(dim, dim);
            for i = 1:n
                tmp = data(i, :) - mus(j, :);
                somme += transpose(tmp) * tmp;
            endfor
            sigmas{j} = (somme * sum_Qij(j)) / sum_Qij(j);
        endfor
        
    endfor
endfunction


clear;
data = load("data/classif/gmm2d.asc");
k = 3;
tic
r = EM(data, k);
toc

