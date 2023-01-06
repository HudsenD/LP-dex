// const { assert, expect } = require("chai")
// const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
// const { developmentChains, networkConfig } = require("../../helper-hardhat-config")

// !developmentChains.includes(network.name)
//     ? describe.skip
//     : describe("Dex Tests", function () {
//           let dex, usdcToken, hdToken, deployer, player
//           const SWAPAMOUNT = ethers.utils.parseEther("0.01")
//           const LIQUIDITYAMOUNT = ethers.utils.parseUnits("1", 8)
//           provider = ethers.provider

//           beforeEach(async function () {
//               deployer = (await getNamedAccounts()).deployer
//               player = (await getNamedAccounts()).player
//               await deployments.fixture(["all"])
//               dex = await ethers.getContract("Dex")
//               usdcToken = await ethers.getContract("UsdcToken")
//               hdToken = await ethers.getContract("HdToken")
//           })
//           describe("createPool", function () {
//               it("creates pool correctly", async function () {
//                   const tx = await dex.createPool(usdcToken.address, hdToken.address)
//                   await tx.wait(1)
//                   assert.equal(true, await dex.isPoolOpen("USDC/HD"))
//               })
//           })
//           describe("swap", function () {
//               it("reverts if pool is closed", async function () {
//                   await expect(dex.swap("USD", usdcToken.address, SWAPAMOUNT)).to.be.revertedWith("PoolClosed")
//               })
//           })
//           describe("addLiquidity", function () {
//               it("deposits tokens correctly", async function () {
//                   const tx = await usdcToken.approve(dex.address, LIQUIDITYAMOUNT)
//                   await tx.wait(1)
//                   await dex.createPool(usdcToken.address, hdToken.address)
//                   const depositTx = await dex.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
//               })
//           })
//           describe("removeLiquidity", function () {
//               it("removes tokens correctly", async function () {
//                   //   const tx = await usdcToken.approve(dex.address, LIQUIDITYAMOUNT)
//                   //   await tx.wait(1)
//                   //   await dex.createPool(usdcToken.address, hdToken.address)
//                   //   const depositTx = await dex.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
//                   //   await depositTx.wait(1)
//                   //   await dex.removeLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
//               })
//               it("reverts if msg.sender has insufficient tokens", async function () {})
//           })
//       })
