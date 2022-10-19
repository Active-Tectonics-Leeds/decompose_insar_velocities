function vstd_scaled = scale_vstd(x,y,vstd)
%=================================================================
% function vstd_scale()
%-----------------------------------------------------------------
% Scale InSAR velocity uncertainties using semivariogram to mitigate the
% impact of the reference pixel.
%                                                                  
% INPUT:                                                           
%   par: parameter structure from readparfile.
%
% OUTPUT:    
%   vstd_scale: scaled uncertainty
%   
% Andrew Watson     19-10-2022
%                                                                  
%=================================================================

%% setup

nbins = 100;

% identfy reference pixel by assuming that min value occurs there
[~,min_ind] = min(vstd(:));
[ref_row,ref_col] = ind2sub(size(vstd),min_ind);

% calculate distance between reference pixel and all others pixels
[xx,yy] = meshgrid(x,y);
ref_dists = sqrt( (xx - xx(ref_row,ref_col)).^2 + (yy - yy(ref_row,ref_col)).^2 );

% calcualte bin medians and SD (hardcoded 100 bins), starting from 0
max_dist = max(ref_dists(:));
bin_edges = linspace(0,max_dist,nbins+1);
bin_mids = bin_edges(1:end-1) + (diff(bin_edges)./2);

bin_medians = zeros(1,nbins);
bin_stds = zeros(1,nbins);

for ii = 1:nbins
    bin_medians(ii) = median(vstd( ref_dists>bin_edges(ii) & ref_dists<=bin_edges(ii+1) ),'all','omitnan');
    bin_stds(ii) = std(vstd( ref_dists>bin_edges(ii) & ref_dists<=bin_edges(ii+1) ),'omitnan');
end

%% fit spherical model

% generate weights
W = 1 ./ (bin_stds + bin_mids./max_dist);

% define objective function to minimise
obj_fun = @(m) sum(((spherical_model(m,bin_mids)-bin_medians).^2).*W,'omitnan');

% starting values
m0 = [1 1 0];

% solve
[m_fit,~,~,~] = fminsearch(obj_fun,m0);

%% scale

vstd_scaled = vstd .* (m_fit(2)./spherical_model(m_fit,ref_dists));

%% plot

% plot 'semivariogram'
figure(); hold on

scatter(ref_dists(:),vstd(:),0.1,'MarkerFaceColor',[110 199 38]./255,'MarkerEdgeColor','k');

plot(bin_mids,bin_medians,'Color',[198 55 188]./255,'LineWidth',2)
plot(bin_mids,bin_medians+bin_stds,'Color',[198 55 188]./255,'LineWidth',1)
plot(bin_mids,bin_medians-bin_stds,'Color',[198 55 188]./255,'LineWidth',1)

plot(bin_mids,spherical_model(m_fit,bin_mids),'Color','k','LineWidth',2)

xlabel('Distance')
ylabel('vstd difference')


% plot original vstd and scale
figure()
tiledlayout(1,2,'TileSpacing','compact');

nexttile
imagesc(x,y,vstd)
colorbar

nexttile
imagesc(x,y,vstd_scaled)
colorbar

%% spherical model

    function out = spherical_model(m,dists)        
        out = m(3) + m(2) .* ( ((3.*dists)./(2.*m(1))) - (dists.^3./(2.*m(1).^3)) );
        out(dists>m(1)) = m(3) + m(2);
    end

end