// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IHestyAccessControl.sol";
import "./interfaces/IRouter.sol";
import "./Constants.sol";


/**
    @title Hesty Access Control

    @notice Hesty Contract that is responsible to
            make the control of all the contracts
            deployed by WorldHesty, Lda.

    @author Pedro G. S. Ferreira
*/
contract HestyAccessControl is IHestyAccessControl, AccessControlDefaultAdminRules, Pausable, Constants{

    uint256 public initialSponsorAmount; // Sponsor initial transactions of users be sending some ETH

    mapping(address => bool)  public kycCompleted;      // Store user KYC status
    mapping(address => bool)  public blackList;         // Store user Blacklist status
    mapping(address => bool)  private firstApproval;    // Store user Blacklist status

    constructor() AccessControlDefaultAdminRules(
        3 days,
        msg.sender // Explicit initial `DEFAULT_ADMIN_ROLE` holder
    ){
        initialSponsorAmount = 0.00025 ether;
    }

    /**======================================

        MODIFIER FUNCTIONS

    =========================================**/

    /**
        @dev Checks that `manager` is an Admin
    */
    modifier onlyAdminManager(address manager){
        require(hasRole(DEFAULT_ADMIN_ROLE, manager), "Not Admin Manager");
        _;
    }

    /**
        @dev Checks that `manager` is funds manger
    */
    modifier onlyFundManager(address manager){
        require(hasRole(FUNDS_MANAGER, manager), "Not Funds Manager");
        _;
    }

    /**
        @dev Checks that `manager` is blackListManager
    */
    modifier onlyBlackListManager(address manager){
        require(hasRole(BLACKLIST_MANAGER, manager), "Not Blacklist Manager");
        _;
    }

    /**
        @dev Checks that `manager` is KYC manager
    */
    modifier onlyKYCManager(address manager){
        require(hasRole(KYC_MANAGER, manager), "Not KYC Manager");
        _;
    }

    /**
        @dev Checks that `manager` is pauser manger
    */
    modifier onlyPauserManager(address manager){
        require(hasRole(PAUSER_MANAGER, manager), "Not Pauser Manager");
        _;
    }

    /**======================================

        MUTABLE FUNCTIONS

    =========================================**/

    /**
        @notice Only Admin
        @param  manager The user that wants to call the function
                onlyOnwer
    */
    function onlyAdmin(address manager) onlyAdminManager(manager) external{}

    /**
        @notice Only Funds Manager
        @param  manager The user that wants to call the function
                onlyFundManager
    */
    function onlyFundsManager(address manager) external onlyFundManager(manager){}

    /**
        @notice Blacklist user
        @param  user The Address of the user
        @dev    Require this approval to allow users move Hesty derivatives
                onlyOnwer
    */
    function blacklistUser(address user) external onlyBlackListManager(msg.sender){
        require(!blackList[user], "Already blacklisted");
        blackList[user] = true;
    }

    /**
        @notice UnBlacklist user
        @param user The Address of the user
        @dev Require this approval to allow users move Hesty derivatives
             onlyOnwer
    */
    function unBlacklistUser(address user) external onlyBlackListManager(msg.sender){
        require(blackList[user], "Not blacklisted");
        blackList[user] = false;
    }

    /**
        @notice Approve user KYC
                @param user The Address of the user
        @dev Require this approval to allow users move Hesty derivatives
             onlyOnwer, in case user has less funds than sponsor amount send a few ETH
    */
    function approveUserKYC(address user) external onlyKYCManager(msg.sender){
        require(!kycCompleted[user], "Already Approved");

        if(!firstApproval[user]){

            firstApproval[user] = true;

            uint256 userBalance = user.balance;

            if(userBalance < initialSponsorAmount && initialSponsorAmount != 0){

                (bool success, ) = user.call{ value:  initialSponsorAmount - userBalance}("");
                require(success, "Sponsoring Failed");

            }
        }

        kycCompleted[user] = true;
    }

    /**
        @dev    Approve KYC only without sponsoring address
        @param  user The Address of the user
    */
    function approveKYCOnly(address user) external onlyKYCManager(msg.sender){
        require(!kycCompleted[user], "Already Approved");
        kycCompleted[user] = true;
    }

    /**
        @notice Revert user KYC status
        @param user The Address of the user
    */
    function revertUserKYC(address user) external onlyKYCManager(msg.sender){
        require(kycCompleted[user], "Not KYC Approved");
        kycCompleted[user] = false;
    }

    /**
        @dev    Pause all Hesty Contracts
        @dev    Require this approval to allow users move Hesty derivatives
                onlyOnwer
    */
    function pause() external onlyPauserManager(msg.sender){
        super._pause();
    }

    /**
        @dev    Unpause all Hesty Contracts
        @dev    Require this approval to allow users move Hesty derivatives
                onlyOnwer
    */
    function unpause() external onlyPauserManager(msg.sender){
        super._unpause();
    }

    /**
        @dev    Set sponsor amount
        @param newAmount New sponsor amount
    */
    function setSponsorAmount(uint256 newAmount) external onlyAdminManager(msg.sender){
        initialSponsorAmount = newAmount;
    }

    /**======================================

        NON MUTABLE FUNCTIONS

    =========================================**/

    /**
        @dev Returns Paused Status
        @dev This pause affects all tokens and in the future all
             the logic of the marketplace
        @return boolean Checks if contracts are paused
    */
    function paused() public override(IHestyAccessControl, Pausable) view returns(bool){
        return super.paused();
    }

    function owner() public  override(IHestyAccessControl, AccessControlDefaultAdminRules) view returns(address){
        return super.owner();
    }

    function confirmAccessControlAdmin(address router) external onlyAdminManager(msg.sender){
        IRouter(router).confirmAccessControlChange();
    }

    // Function to allow deposits to pay for sponsorship
    receive() external payable {}

}
