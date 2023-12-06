import "MetadataViews"
import "TGSLogging"
import "TGSDataCenter"
import "TGSEntity"
import "TGSInterfaces"
import "TGSPlatform"
import "TGSUser"

pub fun main(
    platform: String,
    uid: String,
): UserInfo? {
    let tgsAddr = TGSPlatform.borrowPlatformPublic().owner!.address
    let acct = getAuthAccount(tgsAddr)

    if let ctrlCap = acct
        .borrow<&Capability<&TGSPlatform.Entity{TGSPlatform.PlatformController, TGSLogging.LoggableResource, TGSEntity.EntityPublic, TGSEntity.EntityPrivate}>>
        (from: TGSPlatform.getStandardControllerPath(acct.address))
    {
        if let userAddress = TGSDataCenter.getAddressByThirdpartyUid(platform, uid) {
            let ctrlRef = ctrlCap.borrow() ?? panic("Could not borrow controller reference")
            let user = ctrlRef.borrowUser(userAddress) ?? panic("Could not borrow user reference")
            return UserInfo(
                userAddress,
                user.getLinkedEcosystems()
            )
        }
    }
    return nil
}

pub struct UserInfo {
    pub let address: Address
    pub let identities: [TGSUser.ThirdPartyInfo]

    init(
        _ address: Address,
        _ identities: [TGSUser.ThirdPartyInfo]
    ) {
        self.address = address
        self.identities = identities
    }
}
