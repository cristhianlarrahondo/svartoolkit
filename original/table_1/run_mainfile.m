%==========================================================================
%% housekeeping
%==========================================================================
clear variables;
close all;
userpath('clear');
clc;
tic;

rng('default'); % reinitialize the random number generator to its startup configuration
rng(0);         % set seed

currdir=pwd;
cd ..
get_help_dir_currdir=pwd;
addpath([get_help_dir_currdir,'/helpfunctions']); % set path to helper functions
cd(currdir)


%==========================================================================
%% setup
%==========================================================================
% %number of variables
nvar=3;

% %number of lags
nlag=1;

% %number of predetermined variables
npredetermined=nvar*nlag;

% %--- restrictions on IRF -------------------------------------------------
% horizons to restrict
horizons=0;

% restrictions
Z1=cell(nvar,1);
Z2=cell(nvar,1);
for i=1:nvar
    Z1{i}=zeros(0,numel(horizons)*nvar);
    Z2{i}=zeros(0,numel(horizons)*nvar);
end

% %------------------------------------------------------------------------
% one restriction on the first shock and one on the second shock
Z1{1}=zeros(1,numel(horizons)*nvar);
Z1{1}(1,1)=1;
Z1{2}=zeros(1,numel(horizons)*nvar);
Z1{2}(1,2)=1;

%--------------------------------------------------------------------------
% one restriction on the first shock and one on the second shock
Z2{1}=Z1{2};
Z2{2}=Z1{1};
for i=3:nvar
    Z2{i}=Z1{i};
end


% %------------------------------------------------------------------------
% structures
% %------------------------------------------------------------------------
info1=SetupInfo(nvar,npredetermined,Z1,@(x)chol(x));

% ZIRF()
info1.nlag=nlag;
info1.horizons=horizons;
info1.ZF=@(x,y)ZIRF(x,y);


info2=SetupInfo(nvar,npredetermined,Z2,@(x)chol(x));

% ZIRF()
info2.nlag=nlag;
info2.horizons=horizons;
info2.ZF=@(x,y)ZIRF(x,y);
% %------------------------------------------------------------------------

% %------------------------------------------------------------------------
% reduced form parameters
% %------------------------------------------------------------------------
% inverse wishart parameters
df=nvar;
Phi=eye(nvar);
[~,DI]=iwishrnd(Phi,df);

% normal parameters
Psi   = zeros(npredetermined,nvar);
Omega = eye(npredetermined);
sqrt_Omega=chol(Omega)';

% %------------------------------------------------------------------------
% display restrictions
% %------------------------------------------------------------------------
% for i=1:nvar
%     display(Z1{i});
% end
% for i=1:nvar
%     display(Z2{i});
% end


%==========================================================================
%% main driver
%==========================================================================

tic
N=10;
ratio=zeros(N,1);
ff_h1=@(x)ff_h(x,info1);
ff_h2=@(x)ff_h(x,info2);
zero_restrictions1=@(x)ZeroRestrictions(x,info1);
zero_restrictions2=@(x)ZeroRestrictions(x,info2);


for i=1:N
    
    % random reduced form parameters
    Sigma=iwishrnd(Phi,df,DI);
    B=reshape(kron(chol(Sigma)',sqrt_Omega)*randn(nvar*npredetermined,1),npredetermined,nvar) + Psi;
    w=DrawW(info1);
    
    % transform to structural
    a1=ff_h_inv([vec(B); vec(Sigma); w],info1);
    A0=reshape(a1(1:nvar*nvar),nvar,nvar);
    Aplus=reshape(a1(nvar*nvar+1:end),npredetermined,nvar);
    

    tmp=A0(:,1);
    A0(:,1)=A0(:,2);
    A0(:,2)=tmp;
    tmp=Aplus(:,1);
    Aplus(:,1)=Aplus(:,2);
    Aplus(:,2)=tmp;
    a2=[vec(A0); vec(Aplus)];
    


    % compute volume elements and ratios
    ratio(i,1)=exp(LogVolumeElement(ff_h1,a1,zero_restrictions1) - LogVolumeElement(ff_h2,a2,zero_restrictions2));    

end


format bank
display(ratio')






