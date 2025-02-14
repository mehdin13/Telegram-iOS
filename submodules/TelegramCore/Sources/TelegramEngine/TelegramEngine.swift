import SwiftSignalKit
import Postbox

public final class TelegramEngine {
    public let account: Account

    public init(account: Account) {
        self.account = account
    }

    public lazy var secureId: SecureId = {
        return SecureId(account: self.account)
    }()

    public lazy var peersNearby: PeersNearby = {
        return PeersNearby(account: self.account)
    }()

    public lazy var payments: Payments = {
        return Payments(account: self.account)
    }()

    public lazy var peers: Peers = {
        return Peers(account: self.account)
    }()

    public lazy var auth: Auth = {
        return Auth(account: self.account)
    }()

    public lazy var accountData: AccountData = {
        return AccountData(account: self.account)
    }()

    public lazy var stickers: Stickers = {
        return Stickers(account: self.account)
    }()

    public lazy var peerManagement: PeerManagement = {
        return PeerManagement(account: self.account)
    }()

    public lazy var localization: Localization = {
        return Localization(account: self.account)
    }()

    public lazy var messages: Messages = {
        return Messages(account: self.account)
    }()
}

public final class TelegramEngineUnauthorized {
    public let account: UnauthorizedAccount

    public init(account: UnauthorizedAccount) {
        self.account = account
    }

    public lazy var auth: Auth = {
        return Auth(account: self.account)
    }()

    public lazy var localization: Localization = {
        return Localization(account: self.account)
    }()
}
