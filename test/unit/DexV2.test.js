const { assert, expect } = require("chai")
const { getNamedAccounts, deployments, ethers, network } = require("hardhat")
const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { INITIAL_SUPPLY } = require("../../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("DexV2 Tests", function () {
          let dexV2, usdcToken, hdToken, deployer, player, dexV2Player, usdcTokenPlayer, hdTokenPlayer
          const SWAPAMOUNT = ethers.utils.parseUnits("1", 4)
          const LIQUIDITYAMOUNT = ethers.utils.parseUnits("1", 8)
          const OVERLIQUIDITYAMOUNT = ethers.utils.parseUnits("1.1", 18)
          provider = ethers.provider

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              player = (await getNamedAccounts()).player
              await deployments.fixture(["all"])
              dexV2 = await ethers.getContract("DexV2")
              dexV2Player = await ethers.getContract("DexV2", player)
              usdcToken = await ethers.getContract("UsdcToken")
              usdcTokenPlayer = await ethers.getContract("UsdcToken", player)
              hdToken = await ethers.getContract("HdToken")
              hdTokenPlayer = await ethers.getContract("HdToken", player)
              await usdcToken.approve(deployer, SWAPAMOUNT)
              await usdcToken.transferFrom(deployer, player, SWAPAMOUNT)
              await hdToken.approve(deployer, SWAPAMOUNT)
              await hdToken.transferFrom(deployer, player, SWAPAMOUNT)
          })
          describe("createPool", function () {
              it("creates pool correctly", async function () {
                  const tx = await dexV2.createPool(usdcToken.address, hdToken.address)
                  await tx.wait(1)
                  assert.equal(true, await dexV2.getIsPoolOpen("USDC/HD"))
              })
          })
          describe("swap", function () {
              beforeEach(async function () {
                  await dexV2.createPool(usdcToken.address, hdToken.address)
                  await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await hdToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  await dexV2.addLiquidity("USDC/HD", hdToken.address, LIQUIDITYAMOUNT)
                  const UsdcPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  const HdPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", hdToken.address)
                  //   console.log(`USDC:${UsdcPoolBalance.toString()}`)
                  //   console.log(`HD:${HdPoolBalance.toString()}`)
              })
              it("swaps tokens correctly", async function () {
                  // K constants arent exactly the same due to solidity math, however they are extremely close.
                  const preUsdcPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  const preHdPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", hdToken.address)
                  //   const constantKBeforeSwap = preHdPoolBalance.toNumber() * preUsdcPoolBalance.toNumber()
                  await usdcToken.approve(dexV2.address, SWAPAMOUNT)
                  await dexV2.swap("USDC/HD", usdcToken.address, SWAPAMOUNT)
                  const postUsdcPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  const postHdPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", hdToken.address)
                  //   const constantKAfterSwap = postHdPoolBalance.toNumber() * postUsdcPoolBalance.toNumber()
                  const usdcDifference = postUsdcPoolBalance.toNumber() - preUsdcPoolBalance.toNumber()
                  assert.equal(usdcDifference, SWAPAMOUNT)
              })
              it("reverts if pool is closed", async function () {
                  await expect(dexV2.swap("USD", usdcToken.address, SWAPAMOUNT)).to.be.revertedWith("PoolClosed")
              })
              it("reverts if pool doesn't have enough tokens to swap", async function () {
                  await usdcToken.approve(dexV2.address, OVERLIQUIDITYAMOUNT + SWAPAMOUNT)
                  await dexV2.swap("USDC/HD", usdcToken.address, OVERLIQUIDITYAMOUNT)
                  const UsdcPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  const HdPoolBalance = await dexV2.getTotalPoolBalance("USDC/HD", hdToken.address)
                  //   console.log(`USDC:${UsdcPoolBalance.toString()}`)
                  //   console.log(`HD:${HdPoolBalance.toString()}`)
                  await expect(dexV2.swap("USDC/HD", usdcToken.address, SWAPAMOUNT)).to.be.revertedWith(
                      "ZeroPoolLiquidity"
                  )
              })
          })
          describe("addLiquidity", function () {
              it("deposits tokens, updates pool and user balances correctly", async function () {
                  const tx = await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await tx.wait(1)
                  await dexV2.createPool(usdcToken.address, hdToken.address)
                  const depositTx = await dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  const userBalance = await dexV2.getUserPoolBalance("USDC/HD", usdcToken.address)
                  const poolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  assert.equal(LIQUIDITYAMOUNT, userBalance.toString())
                  assert.equal(LIQUIDITYAMOUNT, poolBalance.toString())
              })
              it("reverts if ERC20 token transfer fails", async function () {
                  await dexV2.createPool(usdcToken.address, hdToken.address)
                  await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT + INITIAL_SUPPLY)
                  await expect(
                      dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT + INITIAL_SUPPLY)
                  ).to.be.revertedWith("ERC20: transfer amount exceeds balance")
              })
          })
          describe("removeLiquidity", function () {
              it("removes tokens, updates pool and user balances correctly", async function () {
                  const tx = await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await tx.wait(1)
                  await dexV2.createPool(usdcToken.address, hdToken.address)
                  const depositTx = await dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  await depositTx.wait(1)
                  await dexV2.removeLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  const userBalance = await dexV2.getUserPoolBalance("USDC/HD", usdcToken.address)
                  const poolBalance = await dexV2.getTotalPoolBalance("USDC/HD", usdcToken.address)
                  assert.equal(0, userBalance.toString())
                  assert.equal(0, poolBalance.toString())
              })
              it("reverts if msg.sender has insufficient tokens", async function () {
                  await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  dexV2.createPool(usdcToken.address, hdToken.address)
                  await dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  await expect(
                      dexV2Player.removeLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  ).to.be.revertedWith("InsufficientUserFunds")
              })
              it("reverts if pool has insufficient tokens", async function () {
                  // get pool made, set up
                  await dexV2.createPool(usdcToken.address, hdToken.address)
                  await usdcToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await hdToken.approve(dexV2.address, LIQUIDITYAMOUNT)
                  await dexV2.addLiquidity("USDC/HD", usdcToken.address, LIQUIDITYAMOUNT)
                  await dexV2.addLiquidity("USDC/HD", hdToken.address, LIQUIDITYAMOUNT)
                  // different user swaps usdc for hd tokens
                  await usdcTokenPlayer.approve(dexV2.address, SWAPAMOUNT)
                  const tx = await dexV2Player.swap("USDC/HD", usdcToken.address, SWAPAMOUNT)
                  await tx.wait(1)
                  // hd tokens are less then what we put in, so should revert
                  await expect(dexV2.removeLiquidity("USDC/HD", hdToken.address, LIQUIDITYAMOUNT)).to.be.revertedWith(
                      "InsufficientPoolFunds"
                  )
              })
          })
          //   describe("getPrice", function () {
          //       it("reverts if pool has zero liquidity", async function () {
          //           await expect(dexV2.getPrice("USDC/HD", hdToken.address, usdcToken.address)).to.be.revertedWith(
          //               "InsufficientPoolLiquidity"
          //           )
          //       })
          //   })
      })
