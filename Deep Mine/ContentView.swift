import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DDMStore

    var body: some View {
        RootTabView()
    }
}
