const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("CrowdFunding", function () {
  let contract;
  let owner, alice, bob;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();

    const CrowdFunding = await ethers.getContractFactory("CrowdFunding");
    contract = await CrowdFunding.deploy();
    await contract.waitForDeployment();
  });

  it("creates a project", async () => {
    await contract.createProject(
      "Test Project",
      "Description",
      ethers.parseEther("0.1"),
      ethers.parseEther("1"),
      1
    );

    const project = await contract.getProjectDetails(0);
    expect(project.projectTitle).to.equal("Test Project");
  });

  it("allows contribution and mints NFT", async () => {
    await contract.createProject(
      "NFT Project",
      "With rewards",
      ethers.parseEther("0.1"),
      ethers.parseEther("1"),
      1
    );

    await contract.connect(alice).participateToProject(0, {
      value: ethers.parseEther("0.2"),
    });

    expect(await contract.balanceOf(alice.address)).to.equal(1);
  });

  it("prevents refunds on successful project", async () => {
    await contract.createProject(
      "Success Project",
      "Goal met",
      0,
      ethers.parseEther("0.5"),
      10
    );

    await contract.connect(alice).participateToProject(0, {
      value: ethers.parseEther("0.5"),
    });

    //The two lines below are also valid for testing. 
    //await ethers.provider.send("evm_increaseTime", [20]);
    //await ethers.provider.send("evm_mine");
    await time.increase(86400 + 100);

    await contract.withdrawFunds(0);

    await expect(
      contract.connect(alice).refund(0)
    ).to.be.reverted;
  });
}); 
