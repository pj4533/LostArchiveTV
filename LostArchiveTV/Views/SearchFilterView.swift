import SwiftUI

struct SearchFilterView: View {
    @Binding var filter: SearchFilter
    @State private var startYear: String = ""
    @State private var endYear: String = ""
    @State private var minFileCount: String = ""
    @State private var maxFileCount: String = ""
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
                
                Section(header: Text("File Count")) {
                    HStack {
                        TextField("Min", text: $minFileCount)
                            .keyboardType(.numberPad)
                            .onChange(of: minFileCount) { _, newValue in
                                if let count = Int(newValue), count > 0 {
                                    filter.minFileCount = count
                                } else {
                                    filter.minFileCount = nil
                                }
                            }
                        
                        Text("to")
                        
                        TextField("Max", text: $maxFileCount)
                            .keyboardType(.numberPad)
                            .onChange(of: maxFileCount) { _, newValue in
                                if let count = Int(newValue), count > 0 {
                                    filter.maxFileCount = count
                                } else {
                                    filter.maxFileCount = nil
                                }
                            }
                    }
                }
                
                Button("Reset Filters") {
                    filter = SearchFilter()
                    startYear = ""
                    endYear = ""
                    minFileCount = ""
                    maxFileCount = ""
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
                if let count = filter.minFileCount {
                    minFileCount = String(count)
                }
                if let count = filter.maxFileCount {
                    maxFileCount = String(count)
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