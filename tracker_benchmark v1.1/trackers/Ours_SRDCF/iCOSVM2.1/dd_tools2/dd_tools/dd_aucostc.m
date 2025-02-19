%DD_AUCOSTC Area under Cost curve
%
%      E = DD_AUCOSTC(R)
%
% Compute the area under the cost curve R, obtained from DD_COSTC.
% This is an alternative to the Area under the ROC curve.
%
% See also: DD_COSTC, DD_AUC

% Copyright: D.M.J. Tax, D.M.J.Tax@prtools.org
% Faculty EWI, Delft University of Technology
% P.O. Box 5031, 2600 GA Delft, The Netherlands

function e = dd_aucostc(a,w)

if nargin==0
   e = prmapping(mfilename,'fixed');
elseif nargin==1
   if ~isfield(a,'pcf') || ~isfield(a,'cost')
      error('R should contain a cost curve (from dd_costc).');
   end
   if (a.pcf(1)~=0)
      error('The prob.cost function should start with 0.');
   end
   if (a.pcf(end)~=1)
      error('The prob.cost function should end with 1.');
   end
   deltax = diff(a.pcf);
   height = (a.cost(1:end-1)+a.cost(2:end))/2;
   e = height'*deltax;
else
   ismapping(w);
   istrained(w);

   e = feval(mfilename,dd_costc(a*w));
end

