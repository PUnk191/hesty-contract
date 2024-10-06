const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Referral System", function () {
  let PropertyFactory;
  let propertyFactory;
  let owner;
  let propertyManager;
  let addr1;
  let addr2;

  beforeEach(async function () {
    [owner, propertyManager, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    HestyAccessControl = await ethers.getContractFactory("HestyAccessControl");
    hestyAccessControlCtr = await HestyAccessControl.connect(owner).deploy();
    await hestyAccessControlCtr.deployed();

    TokenFactory = await ethers.getContractFactory("TokenFactory");
    tokenFactory = await TokenFactory.connect(owner).deploy(300, 1000, 100, owner.address, 1, hestyAccessControlCtr.address);
    await tokenFactory.deployed();

    Token = await ethers.getContractFactory("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20");
    token = await Token.connect(owner).deploy("name", "symbol");
    await token.deployed()

    Referral = await ethers.getContractFactory("ReferralSystem");
    referral = await Referral.connect(owner).deploy(token.address, hestyAccessControlCtr.address, tokenFactory.address);
    await token.deployed()

    /*
    await hestyAccessControlCtr.grantRole(
      await hestyAccessControlCtr.KYC_MANAGER(),
      addr2.address
    );

    await hestyAccessControlCtr.grantRole(
      await hestyAccessControlCtr.PAUSER_MANAGER(),
      addr3.address
    );*/
  });


  it("Basic Getters", async function () {

    expect(await referral.ctrHestyControl()).to.equal(hestyAccessControlCtr.address);

    expect(await referral.rewardToken()).to.equal(token.address);

    expect(await referral.tokenFactory()).to.equal(tokenFactory.address);

  });

  it("Add Approved Contracts", async function () {

    await expect(
      referral.connect(addr3).addApprovedCtrs(addr4.address)
    ).to.be.revertedWith("Not Admin Manager");

    await referral.addApprovedCtrs(addr4.address)

    expect(await referral.approvedCtrs(addr4.address)).to.equal(true);

  });

  it("Remove Approved Contracts", async function () {

    await expect(
      referral.connect(addr3).addApprovedCtrs(addr4.address)
    ).to.be.revertedWith("Not Admin Manager");

    await referral.addApprovedCtrs(addr4.address)

    await referral.removeApprovedCtrs(addr4.address)

    expect(await referral.approvedCtrs(addr4.address)).to.equal(false);

  });

  describe("Add Rewards", function () {

    it("Add rewards new user", async function () {

      await expect(
        hestyAccessControlCtr.blacklistUser(addr2.address)
      ).to.be.revertedWith("Not Blacklist Manager");


      hestyAccessControlCtr.connect(addr1).blacklistUser(propertyManager.address)


    });


  })

});
