
const Web3 = require('web3')
const {
    bridgeTop,topErc20Name,topErc20Symbol,topErc20uuid
} = require('./performparams')
const hardhat = require("hardhat")
var Tx = require("ethereumjs-tx").Transaction

const networks  = require('../hardhat.networks')
const network = networks.topTest
const chainId = network.chainId
const gasLimit = 4000000;

const web3 = new Web3(new Web3.providers.HttpProvider(network.url));

async function deploy(){
   await deployERC20MintProxy()
   await deployEthProver()
   await deployLimit()
   await deployTopErc20Wrapper()
}

async function deployERC20MintProxy(){
    const { getNamedAccounts} = hardhat
    let {
          deployer
    } = await getNamedAccounts()

    const mintProxy = await hre.artifacts.readArtifact("ERC20MintProxy")
    const bytecode = mintProxy.bytecode

    console.log("+++++++++++++deployERC20MintProxy+++++++++++++++ ","")
    await sendTransaction(deployer,bytecode)
}

async function deployEthProver(){
    const { getNamedAccounts} = hardhat
    let {
          deployer
    } = await getNamedAccounts()
    const ethProver = await hre.artifacts.readArtifact("EthProver")
    const bytecode = ethProver.bytecode
    const abi = ethProver.abi
    const contract = new web3.eth.Contract(abi);
    let data = contract.deploy({
        data: bytecode,
        arguments: [bridgeTop]
    }).encodeABI()
    console.log("+++++++++++++deployEthProver+++++++++++++++ ","")
    await sendTransaction(deployer,data)
}

async function deployLimit(){
    const { getNamedAccounts} = hardhat
    let {
          deployer
    } = await getNamedAccounts()

    const limit = await hre.artifacts.readArtifact("Limit")
    const bytecode = limit.bytecode
    console.log("+++++++++++++deployLimit+++++++++++++++ ","")

    await sendTransaction(deployer,bytecode)
}


async function deployTopErc20Wrapper(){
    const { getNamedAccounts} = hardhat
    let {
          deployer
    } = await getNamedAccounts()

    const topErc20Wrapper = await hre.artifacts.readArtifact("TopErc20Wrapper")
    const bytecode = topErc20Wrapper.bytecode
    const abi = topErc20Wrapper.abi
    console.log("+++++++++++++deployTopErc20Wrapper+++++++++++++++ ","")

    const contract = new web3.eth.Contract(abi);

    let data = contract.deploy({
        data: bytecode,
        arguments: [topErc20Name,topErc20Symbol,topErc20uuid]
    }).encodeABI()
    await sendTransaction(deployer,data)

}

async function sendTransaction(deployer,data){
    var fromAddr = deployer;
    var count = await web3.eth.getTransactionCount(fromAddr);
    var gasPrice = await web3.eth.getGasPrice();
    console.log("+++++++++++++gasPrice+++++++++++++++ ",web3.utils.toHex(gasPrice))

    var privateKey = new Buffer.from(network.accounts[0], 'hex');

    var rawTx = {
        'from': fromAddr,
        'nonce': web3.utils.toHex(count),
        'gasPrice': web3.utils.toHex(gasPrice),
        'gasLimit': web3.utils.toHex(gasLimit),
        'value': '0x0',
        'data': data
    };
   
    const tx = new Tx(rawTx, {chain: chainId})
    tx.sign(privateKey);
    var serializedTx = tx.serialize();
    var hashTx = await web3.eth.sendSignedTransaction('0x'+serializedTx.toString('hex'));
    console.log('contractAddress: ' + hashTx.contractAddress);
}

deploy()