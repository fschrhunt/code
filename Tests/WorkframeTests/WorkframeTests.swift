import Testing
@testable import WorkframeCore

@Test func parsesMachineReadableWorktrees() {
    let rows = WorkframeOutput.workspaces("task\tapi\toslo\t/tmp/workframe/workspaces/api/oslo\tpayment-retry\n")

    #expect(rows == [Workspace(agent: "task", repository: "api", city: "oslo", path: "/tmp/workframe/workspaces/api/oslo", branch: "payment-retry")])
    #expect(rows[0].feature == "payment-retry")
    #expect(rows[0].location == "oslo")
}

@Test func ignoresMalformedMachineReadableRows() {
    let rows = WorkframeOutput.archived("bad row\ndark-mode\tweb\tdark-mode\t2 hours ago\n")

    #expect(rows.count == 1)
    #expect(rows[0].repository == "web")
    #expect(rows[0].feature == "dark-mode")
}

@Test func parsesAnAvailableHomebrewCaskUpdate() {
    let output = #"{"formulae":[],"casks":[{"token":"workframe","installed_versions":["1.5.0"],"current_version":"1.6.0"}]}"#

    #expect(HomebrewOutput.caskUpdate(output, token: "workframe") == HomebrewCaskUpdate(
        token: "workframe",
        installedVersion: "1.5.0",
        availableVersion: "1.6.0"
    ))
}

@Test func ignoresCurrentAndMalformedHomebrewCaskOutput() {
    let current = #"{"formulae":[],"casks":[{"token":"workframe","installed_versions":["1.5.0"],"current_version":"1.5.0"}]}"#

    #expect(HomebrewOutput.caskUpdate(current, token: "workframe") == nil)
    #expect(HomebrewOutput.caskUpdate("not json", token: "workframe") == nil)
}
