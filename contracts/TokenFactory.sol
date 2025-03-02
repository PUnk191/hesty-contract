// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PropertyToken} from "./PropertyToken.sol";
import "./interfaces/IHestyAccessControl.sol";
import "./interfaces/ITokenFactory.sol";
import {IIssuance} from "./interfaces/IIssuance.sol";
import "./interfaces/IReferral.sol";
import "./Constants.sol";



contract TokenFactory is
ReentrancyGuard,
Constants {

    IHestyAccessControl public ctrHestyControl;     // Hesty Access Control Contract
    IIssuance           public ctrHestyIssuance;    // Hesty Tokens Issuance Logic
    IReferral           public referralSystemCtr;   // Referral System Contract

    uint256 public propertyCounter;         // Number of properties created until now
    uint256 public minInvAmount;            // Minimum amount allowed to invest
    uint256 public maxNumberOfReferrals;    // Maximum Number of Referrals that a user can have
    uint256 public maxAmountOfRefRev;       // Maximum Amount of Referral Revenue users can earn
    uint256 public platformFeeBasisPoints;  // Investment Fee charged by Hesty (in Basis Points)
    uint256 public refFeeBasisPoints;       // Referral Fee charged by referrals (in Basis Points)
    address public treasury;                // Address that will receive Hesty fees revenue
    bool    public initialized;            // Checks if the contract is already initialized

    mapping(uint256 => PropertyInfo)    public property;                // Stores properties info
    mapping(uint256 => uint256)         public platformFee;             // (Property id => fee amount) The fee earned by the platform on every investment
    mapping(uint256 => uint256)         public ownersPlatformFee;       // The fee earned by the platform on every investment
    mapping(uint256 => uint256)         public propertyOwnerShare;      // The amount reserved to propertyOwner
    mapping(uint256 => uint256)         public refFee;                  // The referral fee accumulated by each property before completing
    mapping(uint256 => uint256)         public ownersFeeBasisPoints;    // Owners Fee charged by Hesty (in Basis Points) in each project
    mapping(uint256 => bool)            public deadProperty;            // After Canceled can no longer be approved
    mapping(address => bool)            public tokensWhitelist;         // Payment Token whitelist

    mapping(address => mapping(uint256 => uint256)) public userInvested;    // Amount invested by each user in each property
    mapping(address => mapping(uint256 => uint256)) public rightForTokens;  // Amount of tokens that each user bought

    //Events
    event              InitializeFactory(address referralCtr, address ctrHestyIssuance_);
    event                 CreateProperty(uint256 id);
    event           NewReferralSystemCtr(address newSystemCtr);
    event           NewIssuanceContract(address newIssuanceCtr);
    event                    NewTreasury(address newTreasury);
    event   NewPropertyOwnerAddrReceiver(address newAddress);
    event                  NewInvestment(uint256 indexed propertyId, address investor, uint256 amount, uint256 amountSpent, uint256 date);
    event                 RevenuePayment(uint256 indexed propertyId, uint256 amount);
    event                 CancelProperty(uint256 propertyId);
    event                 NewPlatformFee(uint256 newFee);
    event               NewMaxNReferrals(uint256 newNumber);
    event          NewMaxReferralRevenue(uint256 newAmount);
    event            NewPropertyDeadline(uint256 propertyId, uint256 newDeadline);
    event                   NewOwnersFee(uint256 indexed id, uint256 newFee);
    event                 NewReferralFee(uint256 newFee);
    event         NewMinInvestmentAmount(uint256 minInvestmentAmount);
    event                   ClaimProfits(address indexed user, uint256 propertyId);
    event                  CompleteRaise(uint256 propertyId);
    event                   RecoverFunds(address indexed user, uint256 propertyId);
    event                ApproveProperty(uint256 propertyId, uint256 newDeadline);
    event            GetInvestmentTokens(address indexed user, uint256 propertyId);
    event              AddWhitelistToken(address token);
    event           RemoveWhitelistToken(address token);


    struct PropertyInfo{
        uint256 price;          // Price for each property token
        uint256 amountToSell;   // Amount of tokens to sell
        uint256 threshold;      // Amount necessary to proceed with investment
        uint256 raised;         // Amount tokens sold
        uint256 raiseDeadline;  // When the fundraising ends
        bool    isCompleted;    // Checks if the raise is completed
        bool    approved;       // Checks if the raise can start
        bool    extended;       // Checks if the raise was already extended
        address owner;          // Hesty owner
        address ownerExchAddr;  // Property Owner/Manager exchange address to receive EUROC
        IERC20 paymentToken;    // Token used to buy property tokens/assets
        address asset;          // Property token contract
        IERC20 revenueToken;    // Revenue token for investors

    }


    constructor(
        uint256 fee,
        uint256 refFee_,
        address treasury_,
        uint256 minInvAmount_,
        address ctrHestyControl_
    ){

        require(refFee_ < fee, "Ref fee invalid");
        require(fee < MAX_FEE_POINTS, "Invalid Platform Fee");

        platformFeeBasisPoints  = fee;
        refFeeBasisPoints       = refFee_;
        minInvAmount            = minInvAmount_;
        treasury                = treasury_;
        maxNumberOfReferrals    = 20;               // Start with max 20 referrals
        maxAmountOfRefRev       = 10000 * WAD;      // Start with max 10000€ of revenue
        initialized             = false;
        ctrHestyControl         = IHestyAccessControl(ctrHestyControl_);

    }

   
    modifier onlyAdmin(){
        ctrHestyControl.onlyAdmin(msg.sender);
        _;
    }

  
    modifier onlyFundsManager(){
        ctrHestyControl.onlyFundsManager(msg.sender);
        _;
    }

   
    modifier onlyWhenInitialized(){
        require(initialized, "Not yet init");
        _;
    }

    
    modifier whenNotBlackListed(){
        require(!ctrHestyControl.blackList(msg.sender), "Blacklisted");
        _;
    }

   
    modifier whenKYCApproved(address user){
        require(ctrHestyControl.kycCompleted(user), "No KYC Made");
        _;
    }


    modifier whenNotAllPaused(){
        require(!ctrHestyControl.paused(), "All Hesty Paused");
        _;
    }

    function initialize(address referralSystemCtr_,
        address ctrHestyIssuance_) external onlyAdmin{

        require(!initialized, "Already init");

        initialized       = true;
        referralSystemCtr = IReferral(referralSystemCtr_);
        ctrHestyIssuance = IIssuance(ctrHestyIssuance_);

        emit InitializeFactory(referralSystemCtr_, ctrHestyIssuance_);

    }
    
    function createProperty(
        uint256 amount,
        uint256 listingTokenFee,
        uint256 tokenPrice,
        uint256 threshold,
        address paymentToken,
        address revenueToken,
        string memory name,
        string memory symbol,
        address admin
    ) external whenKYCApproved(msg.sender) onlyWhenInitialized whenNotAllPaused whenNotBlackListed returns(uint256) {

        require(tokensWhitelist[paymentToken] && tokensWhitelist[revenueToken], "Invalid pay token");
        require( listingTokenFee < MAX_FEE_POINTS, "Fee must be valid");

        address newAsset = IIssuance(ctrHestyIssuance).createPropertyToken(
            amount,
            address(revenueToken),
            name,
            symbol,
            admin,
            ctrHestyControl.owner() );

        property[propertyCounter++] = PropertyInfo( tokenPrice,
                                                    amount,
                                                    threshold,
                                                    0,
                                                    0,
                                                    false,
                                                    false,
                                                    false,
                                                    msg.sender,
                                                    msg.sender,
                                                    IERC20(paymentToken),
                                                    newAsset,
                                                    IERC20(revenueToken));

        ownersFeeBasisPoints[propertyCounter - 1] = listingTokenFee;

        emit CreateProperty(propertyCounter - 1);

        return propertyCounter - 1;
    }
 
    function buyTokens(
        address onBehalfOf,
        uint256 id,
        uint256 amount,
        address ref
    ) external nonReentrant whenNotAllPaused whenKYCApproved(msg.sender) whenNotBlackListed{

        PropertyInfo storage p = property[id];

        uint256 boughtTokensPrice = amount * p.price;

        require(p.raiseDeadline >= block.timestamp, "Raise expired");
        require(boughtTokensPrice >= minInvAmount, "Lower than min");
        require(property[id].approved && !property[id].isCompleted, "Property Not For Sale");
        require(p.raised + amount <= p.amountToSell, "Too much raised");

        uint256 fee    = boughtTokensPrice * platformFeeBasisPoints / BASIS_POINTS;
        uint256 total  = boughtTokensPrice + fee;

        SafeERC20.safeTransferFrom(p.paymentToken,msg.sender, address(this), total);

        platformFee[id]                += fee;
        userInvested[msg.sender][id]   += boughtTokensPrice;
        rightForTokens[onBehalfOf][id] += amount;

        uint256 ownersFee = boughtTokensPrice * ownersFeeBasisPoints[id] / BASIS_POINTS;

        ownersPlatformFee[id]  += ownersFee;
        propertyOwnerShare[id] += boughtTokensPrice - ownersFee;

        referralRewards(onBehalfOf, ref, boughtTokensPrice, id);

        p.raised     += amount;
        property[id] = p;

        emit NewInvestment(id, onBehalfOf, amount, boughtTokensPrice, block.timestamp);
    }

    function referralRewards(address onBehalfOf, address ref, uint256 boughtTokensPrice, uint256 id) internal{

        if(ref != address(0)){

            (uint256 userNumberRefs,uint256 userRevenue,) = referralSystemCtr.getReferrerDetails(ref);

            uint256 refFee_ = boughtTokensPrice * refFeeBasisPoints / BASIS_POINTS;

            uint256 maxAmountOfLocalRefRev = (maxAmountOfRefRev >= userRevenue ) ? maxAmountOfRefRev : userRevenue;

            refFee_ = (userRevenue + refFee_ > maxAmountOfLocalRefRev) ? maxAmountOfLocalRefRev - userRevenue : refFee_;

            /// @dev maxNumberOfReferral = 20 && maxAmountOfRefRev = €10000
            if(userNumberRefs < maxNumberOfReferrals && refFee_ > 0){

                try referralSystemCtr.addRewards(ref, onBehalfOf,id, refFee_){
                    refFee[id] += refFee_;

                }catch{

                }
            }
        }
    }

    function distributeRevenue(uint256 id, uint256 amount) external nonReentrant whenNotAllPaused{

        PropertyInfo storage p = property[id];

        require(p.isCompleted, "Time not valid");

        SafeERC20.safeTransferFrom(p.revenueToken, msg.sender, address(this), amount);
        SafeERC20.forceApprove(p.revenueToken, p.asset, amount);
        PropertyToken(p.asset).distributionRewards(amount);

        emit RevenuePayment(id, amount);

    }

    function getInvestmentTokens(address user, uint256 id) external nonReentrant whenNotAllPaused{

        PropertyInfo storage p = property[id];

        require(p.isCompleted, "Time not valid");

        if(rightForTokens[user][id] > 0){
            SafeERC20.safeTransfer(IERC20(p.asset), user, rightForTokens[user][id]);
            rightForTokens[user][id] = 0;
        }


        emit GetInvestmentTokens(user, id);
    }

    function claimInvestmentReturns(address user, uint256 id) external nonReentrant whenNotAllPaused{

        PropertyInfo storage p = property[id];

        require(p.isCompleted, "Time not valid");

        PropertyToken(p.asset).claimDividensExternal(user);

        emit ClaimProfits(user, id);
    }

    function recoverFundsInvested(address user, uint256 id) external nonReentrant whenNotAllPaused {

        PropertyInfo storage p = property[id];

        require(p.raiseDeadline < block.timestamp && !p.isCompleted, "Time not valid"); // @dev it must be < not <=
        require(p.raised * p.price < p.threshold, "Threshold reached, cannot recover funds");

        uint256 amount         = userInvested[user][id];
        userInvested[user][id] = 0;
        rightForTokens[user][id] = 0;

        SafeERC20.safeTransfer(p.paymentToken, user, amount);

        emit RecoverFunds(user, id);

    }

    function isRefClaimable(uint256 id) external view returns(bool){
        return property[id].threshold <= property[id].raised * property[id].price && property[id].isCompleted;
    }

    function getPropertyInfo(uint256 id) external view returns(address, address){
        return (address(property[id].asset), address(property[id].revenueToken));
    }

    function adminBuyTokens(uint256 id, address buyer, uint256 amount) whenKYCApproved(buyer) external nonReentrant onlyFundsManager{

        PropertyInfo storage p    = property[id];

        require(p.raiseDeadline >= block.timestamp, "Raise expired");
        require(p.raised + amount <= p.amountToSell, "Too much raised");

        uint256 boughtTokensPrice = amount * p.price;

        rightForTokens[buyer][id] += amount;

        p.raised += amount;
        property[id] = p;

        emit NewInvestment(id, buyer, amount, boughtTokensPrice, block.timestamp);
    }

    function completeRaise(uint256 id) external onlyAdmin {

        PropertyInfo storage p = property[id];

        require(p.approved && !p.isCompleted, "Canceled or Already Completed");
        require(p.raised * p.price >= property[id].threshold , "Threshold not met");

        property[id].isCompleted = true;

        SafeERC20.safeTransfer(p.paymentToken, treasury, platformFee[id] - refFee[id]);
        platformFee[id] = 0;

        SafeERC20.safeTransfer(p.paymentToken,treasury,  ownersPlatformFee[id]);
        ownersPlatformFee[id] = 0;

        SafeERC20.safeTransfer(p.paymentToken,p.ownerExchAddr, propertyOwnerShare[id]);
        propertyOwnerShare[id] = 0;

        SafeERC20.safeTransfer(p.paymentToken,address(referralSystemCtr), refFee[id]);
        refFee[id] = 0;

        emit CompleteRaise(id);
    }

    function approveProperty(uint256 id, uint256 raiseDeadline) external onlyAdmin{

        require(!property[id].approved, "Already Approved");
        require(!deadProperty[id], "Already Canceled");

        property[id].approved = true;
        property[id].raiseDeadline = raiseDeadline;

        emit ApproveProperty(id, raiseDeadline);
    }

    function cancelProperty(uint256 id) external onlyAdmin{

        property[id].raiseDeadline = 0; // Important to allow investors to recover funds
        property[id].approved = false;  // Prevent more investments
        deadProperty[id] = true;

        emit CancelProperty(id);
    }

    function setPlatformFee(uint256 newFee) external onlyAdmin{

        require(newFee < MAX_FEE_POINTS && newFee > refFeeBasisPoints, "Fee must be valid");
        platformFeeBasisPoints = newFee;

        emit NewPlatformFee(newFee);
    }

    function setOwnersFee(uint256 id, uint256 newFee) external onlyAdmin{

        require( newFee < MAX_FEE_POINTS, "Fee must be valid");
        ownersFeeBasisPoints[id] = newFee;

        emit NewOwnersFee(id, newFee);
    }

    function setRefFee(uint256 newFee) external onlyAdmin{

        require( newFee < platformFeeBasisPoints, "Fee must be valid");
        refFeeBasisPoints = newFee;

        emit NewReferralFee(newFee);
    }

    function setNewPropertyOwnerReceiverAddress(uint256 id, address newAddress) external onlyAdmin{

        require( newAddress != address(0), "Address must be valid");
        property[id].ownerExchAddr = newAddress;

        emit NewPropertyOwnerAddrReceiver(newAddress);
    }

    function extendRaiseForProperty(uint256 id, uint256 newDeadline) external onlyAdmin{

        PropertyInfo storage p = property[id];

        require(p.raiseDeadline < newDeadline && p.raiseDeadline + EXTENDED_TIME >= newDeadline  && !p.extended, "Invalid deadline");
        property[id].raiseDeadline = newDeadline;
        property[id].extended = true;

        emit NewPropertyDeadline(id, newDeadline);
    }

    function setMinInvAmount(uint256 newMinInv) external onlyAdmin{
        require(newMinInv > 0, "Amount too low");
        minInvAmount = newMinInv;

        emit NewMinInvestmentAmount(newMinInv);
    }

    function setMaxNumberOfReferrals(uint256 newMax) external onlyAdmin{

        maxNumberOfReferrals = newMax;

        emit NewMaxNReferrals(newMax);
    }
    function setMaxAmountOfRefRev(uint256 newMax) external onlyAdmin{

        maxAmountOfRefRev = newMax;

        emit NewMaxReferralRevenue(newMax);
    }

     function setTreasury(address newTreasury) external onlyAdmin{

        require(newTreasury != address(0), "Not allowed");
        treasury = newTreasury;

        emit NewTreasury(newTreasury);
    }

    function setReferralContract(address newReferralContract) external onlyAdmin{

        require(newReferralContract != address(0), "Not allowed");
        referralSystemCtr = IReferral(newReferralContract);

        emit NewReferralSystemCtr(newReferralContract);
    }

    function setIssuanceContract(address newIssuanceCtr) external onlyAdmin{

        require(newIssuanceCtr != address(0), "Not allowed");
        ctrHestyIssuance = IIssuance(newIssuanceCtr);

        emit NewIssuanceContract(newIssuanceCtr);
    }

    function addWhitelistedToken(address newToken) external onlyAdmin{

        require(newToken != address(0), "Not allowed");

        tokensWhitelist[newToken] = true;

        emit AddWhitelistToken(newToken);
    }

    function removeWhitelistedToken(address oldToken) external onlyAdmin{

        require(tokensWhitelist[oldToken], "Not Found");

        tokensWhitelist[oldToken] = false;

        emit RemoveWhitelistToken(oldToken);
    }

}
