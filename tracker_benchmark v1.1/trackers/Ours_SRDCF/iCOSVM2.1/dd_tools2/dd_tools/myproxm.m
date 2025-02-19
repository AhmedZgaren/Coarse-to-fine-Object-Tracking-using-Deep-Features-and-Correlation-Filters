%MYPROXM MyProximity mapping
% 
% 	W = MYPROXM(A,TYPE,P,G)
% 
% Computation of the k*m proximity mapping (or kernel) defined by 
% the m*k dataset A. 
% The proximities are defined by the following possible TYPEs: 
% 
% 	'linear'      | 'l':   a*b'
% 	'polynomial'  | 'p':   sign(a*b'+1).*(a*b'+1).^p
% 	'exponential' | 'e':   exp(-(||a-b||)/p)
% 	'radial_basis'| 'r':   exp(-(||a-b||.^2)/(p*p))
% 	'r_5nn'            :  like 'r', but with p the average 5-NN dist.
% 	'r_sqrtp'          :  like 'r', but with p the sqrt(dim)
% 	'sigmoid'     | 's':   sigm((sign(a*b').*(a*b'))/p)
% 	'distance'    | 'd':   ||a-b||.^p
% 	'minkowski'   | 'm':   sum(|a-b|^p).^(1/p)
% 	'city-block'  | 'c':   sum(|a-b|)
% 	'gower'       | 'g':   gower-dissimilarity (see gower.m)
%	'kcenter'     | 'k':   k-center prototype 
% 
% In the polynomial case and p not integer D is computed by D = 
% sign(d)*abs(d).^p in order to avoid problems with negative inner 
% products d. The features of the objects in A may be weighted 
% by the weights in the vector g (default 1).
% 
% Default is the Euclidean distance: type = 'distance', p = 1
%
%
% 	W = MYPROXM(A,TYPE,P,G,NR_PROTO)
% 	W = MYPROXM(A,TYPE,P,G,FRAC_PROTO)
%
% For situations where the dataset is (very) large, you can subsample
% the dataset and randomly choose NR_PROTO prototypes (or a fraction
% FRAC_PROTO of the dataset).
% 
% See also mappings, datasets, gower, sqeucldistm

% Copyright: D.M.J. Tax, D.M.J.Tax@prtools.org
% Faculty EWI, Delft University of Technology
% P.O. Box 5031, 2600 GA Delft, The Netherlands

function W = myproxm(A,type,s,g,subs)
		prtrace(mfilename);

if nargin < 5, subs = []; end
if nargin < 4 || isempty(g), g = []; end
if nargin < 3 || isempty(s), s = 1; end
if nargin < 2 || isempty(type), type = 'd'; end
if nargin < 1 || isempty(A),
	W = prmapping(mfilename,{type,s,g,subs});
	W = setname(W,makeproxname(type,s));
	return
end

%A = prdataset(A); % why do I need this??
[m,k] = size(A);
  
% Definition, just store it
if ischar(type)
	
	% Check the inputs, to avoid problems later.
	all = char('polynomial','p','exponential','e','radial_basis','r', ...
             'sigmoid','s','distance','d','minkowski','m',...
             'city-block','c','gower','g','linear','l', 'kcenter','k');
	if ~any(strcmp(cellstr(all),type))
		error(['Unknown proximity type: ' type])
	end
	
	% only one mapping is really trained:
	switch type
	case {'kcenter' 'k'}
		if isempty(g)   % g defines the distance type
			% Euclidean distance
			g = {'d' 2};
			D = sqrt(sqeucldistm(+A,+A));
		else
			D = +(A*myproxm(A,g{1},g{2}));
		end
		D(1:(size(D,1)+1):end) = 0;
		[lab,J] = kcentres(D,s,5,[]);  % 5 repetition
		W = myproxm(A(J,:),g{1},g{2});
		W = setname(W,sprintf('%s (%d protot)',getname(W),length(J)));
	otherwise     
		% per default, only store the data
		% if you supply SUBS, a number of fraction of the objects are used
		% as prototypes.
		if ~isempty(subs)
			if subs>=1
				n = subs;
			else
				n = ceil(subs*size(A,1));
			end
			J = randperm(size(A,1));
			A = A(J(1:n),:);
		end
		W.A = A;
		W.type = type;
		W.s = s;
		W.g = g;
		if isdataset(A)
			W = prmapping(mfilename,'trained',W,getlab(A), ...
															getfeatsize(A),getobjsize(A));
		else
			W = prmapping(mfilename,'trained',W,[],k,m);
		end
		W = setname(W,makeproxname(type,s));
	end
										   
elseif ismapping(type)
% Execution, input data A and W.A, output in D (-->W)

	W = getdata(type);
	[kk,n] = size(type);

	if k ~= kk, error('Matrices should have equal numbers of columns'); end
	
	if ~isempty(W.g)
		if length(W.g) ~= k, error('Weight vector has wrong length'); end
		A = +A.*(ones(m,1)*W.g(:)');
		W.A = +W.A.*(ones(n,1)*W.g(:)');
	end

	switch W.type
	case {'linear','l'}
		D = +(A*W.A'); 

	case {'polynomial','p'}
		D = +(A*W.A'); 
		D = D + ones(m,n);
		if length(W.s)>1, error('Only scalar parameter P possible'); end
		if W.s ~= round(W.s)
			D = sign(D).*abs(D).^W.s;
		elseif W.s ~= 1
			D = D.^W.s;
		end
	
	case {'sigmoid','s'}
		if length(W.s)>1, error('Only scalar parameter P possible'); end
		D = +(A*W.A'); 
		D = sigm(D/W.s);
		
	case {'city-block','c'}
		D = zeros(m,n);
		for j=1:n
			D(:,j) = sum(abs(A - repmat(+(W.A(j,:)),m,1)),2);
		end
		
	case {'minkowski','m'}
		if length(W.s)>1, error('Only scalar parameter P possible'); end
		D = zeros(m,n);
		if isfinite(W.s)
			for j=1:n
				D(:,j) = sum(abs(A - repmat(+(W.A(j,:)),m,1)).^W.s,2).^(1/W.s);
			end
		else
			for j=1:n
				D(:,j) = max(abs(+A - repmat(+(W.A(j,:)),m,1)),[],2);
			end
		end
		
	case {'exponential','e'}
		if length(W.s)>1, error('Only scalar parameter P possible'); end
		D = sqeucldistm(+A,+W.A);
		D = exp(-sqrt(D)/W.s);
		
	case {'radial_basis','r'}
		if length(W.s)>1, error('Only scalar parameter P possible'); end
		D = sqeucldistm(+A,+W.A);
		D = exp(-D/(W.s*W.s));
		
	case {'r_5nn'}
		W.s = nndist(+A,5);
		D = sqeucldistm(+A,+W.A);
		D = exp(-D/(W.s*W.s));
		
	case {'r_sqrtp'}
		W.s = sqrt(size(A,2));
		D = sqeucldistm(+A,+W.A);
		D = exp(-D/(W.s*W.s));
		
	case {'distance','d'}
		D = sqeucldistm(+A,+W.A);
		if W.s ~= 2
			D = sqrt(D).^W.s(1);
		end
		if length(W.s)>1
			D = 2./(1+exp(-D./W.s(2))) - 1;
		end

	case {'gower', 'g'} 
		[feattype,featrange] = getfeattype(W.A);
		ft2 = getfeattype(A);
		if any(feattype~=ft2),
			error('Both datasets have to have the same discrete features');
		end
		D = zeros(m,n);
		for j=1:m
			D(j,:) = gower(+A(j,:),+W.A,feattype,featrange)';
		end
		
	case {'kcenter', 'k'} 
		D = A*W.A;

	otherwise
		error('Unknown proximity type')
	end
	W = setdat(A,D,type);
	
else
	error('Illegal arguments')
end

return

function kname = makeproxname(type,s)

switch type
case {'linear','l'}
	kname = 'linear K';
case {'polynomial','p'}
	kname = sprintf('polyn degree %d',s);
case {'sigmoid','s'}
	kname = sprintf('sigmoid s=%.2f',s);
case {'city-block','c'}
	kname = 'cityblock K';
case {'minkowski','m'}
	kname = sprintf('minkowski p=%d',s);
case {'exponential','e'}
	kname = sprintf('exp.Kernel p=%.2f',s);
case {'radial_basis','r'}
	kname = sprintf('RBF.Kernel s=%.2f',s);
case {'distance','d'}
	kname = sprintf('Eucl.Kernel d=%f',s(1));
case {'gower', 'g'} 
	kname = 'Gower K';
otherwise
	kname = 'Myproxm';
end

return
