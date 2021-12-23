def gasToUSD(gas):
    gwei = 63
    inGwei = gas * gwei
    inEth = inGwei * .000000001
    ethprice = 4120
    inUSD = inEth * ethprice
    print("inETH: ", inEth)
    print("inUSD: ", inUSD)


gasToUSD(287411)
