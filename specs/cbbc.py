import datetime
import time


class address:
    # Ethereum Address
    pass


class MarginVault:
    # Vault that holds the margin deposited by the issuers
    def __init__(self, issuer, initial_margin_rate, maintainance_margin_rate):
        self.issuer = issuer
        self.maintainance_margin_rate = maintainance_margin_rate
        self.initial_margin_rate = initial_margin_rate
        self.margin_balance = 0
        self.status = None  # ['SAFE','WARNING','MARGIN_CALL','LIQUDATE']

    def deposit_margin(self, token: address, amount: int):
        self.margin_balance = self.margin_balance + amount


class PremiumVault:
    # Valut that holds the premium collected from the cbbc buyers
    def __init__(self):
        pass


class CBBC:
    def __init__(self,
                 type: str['BULL', 'BEAR'],
                 underlying: str['BTC', 'ETH', 'SOL'],
                 strike: int,
                 expiry_timestamp: int,  # timestamp
                 conversion_ratio: int,  # 1000
                 issuer: address,
                 holders: dict,  # {address:amount}
                 margin_vault: MarginVault,
                 premium_vault: PremiumVault):
        ###
        self.type = type
        self.underlying = underlying
        self.strike = strike
        self.expiry_timestamp = expiry_timestamp
        self.conversion_ratio = conversion_ratio
        self.issuer = issuer
        self.holders = holders
        self.margin_vault = margin_vault
        self.premium_vault = premium_vault
        ###
        self.called = False
        self.issurance_timestamp = datetime.datetime.now().timestamp()

    def get_ticker(self):
        return f"{self.underlying}-{self.strike}-{self.expiry_timestamp.strftime('%Y%m%d%H')}-{self.type}-{self.issuer[:5]}"

    def update_spot_price(self):
        # get underlying spot price from Oracle
        self.spot = None

    def calc_intrinsic_value(self):
        intrinsic_value = self.spot - self.strike
        if intrinsic_value <= 0:
            self.called = True
            return 0
        else:
            return intrinsic_value

    def deposit_margin(self):

    @only_issuer
    def mint_cbbc(self, margin_valut: MarginVault):
        pass

    def buy_cbbc(self, premium_vault: PremiumVault):
        pass
