const Crowdsale = artifacts.require("./Crowdsale.sol")

module.exports = function(deployer, network, accounts) {
  const startTime = web3.eth.getBlock(web3.eth.blockNumber).timestamp + 240 // seconds
  const endTime = startTime + (86400 * 241); // End on 31st December 2018
  const rate = new web3.BigNumber(0.0227272727272727); // 1/44 (1 ETC should incept 44 NCC)
  deployer.deploy(Crowdsale, startTime, endTime, rate, { gas: 2000000 })
};
