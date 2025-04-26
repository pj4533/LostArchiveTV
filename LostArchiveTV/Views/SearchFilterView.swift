import SwiftUI

struct SearchFilterView: View {
    @Binding var filter: SearchFilter
    @State private var startYear: String = ""
    @State private var endYear: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Year Range")) {
                    HStack {
                        TextField("From", text: $startYear)
                            .keyboardType(.numberPad)
                            .onChange(of: startYear) { _, newValue in
                                if let year = Int(newValue), year > 0 {
                                    filter.startYear = year
                                } else {
                                    filter.startYear = nil
                                }
                            }
                        
                        Text("to")
                        
                        TextField("To", text: $endYear)
                            .keyboardType(.numberPad)
                            .onChange(of: endYear) { _, newValue in
                                if let year = Int(newValue), year > 0 {
                                    filter.endYear = year
                                } else {
                                    filter.endYear = nil
                                }
                            }
                    }
                }
                
                Button("Reset Filters") {
                    filter = SearchFilter()
                    startYear = ""
                    endYear = ""
                }
                .foregroundColor(.red)
            }
            .onAppear {
                // Initialize UI from filter
                if let year = filter.startYear {
                    startYear = String(year)
                }
                if let year = filter.endYear {
                    endYear = String(year)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}