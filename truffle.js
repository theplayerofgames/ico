module.exports = {
  networks: {
    "classic": {
      network_id: 1,
      from: process.env.CREATOR_ACCOUNT, // default address to use for any transaction Truffle makes during migrations
      host: "localhost",
      gas: 2000000,
      port: 8545
    }
  },
  solc: { optimizer: { enabled: true, runs: 200 } }
};
