import "TGSPlatform"

transaction(to: Address) {
    prepare(admin: AuthAccount) {
        let platform = admin.borrow<&TGSPlatform.Entity>(from: TGSPlatform.TGSPlatformStoragePath)
            ?? panic("Failed to borrow a reference to the TGSPlatform")
        // publish first
        platform.publishControllerCapability(to: to)
    }
}
