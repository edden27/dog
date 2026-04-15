// Exercises: string.regex — Swift regex literals
import Foundation

let pattern = /\d{3}-\d{3}-\d{4}/
let email = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/
let url = /https?:\/\/[\w\-]+(\.[\w\-]+)+[\/\w\-._~:?#\[\]@!$&'()*+,;=%]*/

func validatePhone(_ input: String) -> Bool {
    input.wholeMatch(of: /\(\d{3}\)\s?\d{3}-\d{4}/) != nil
}

let csv = /(?:^|,)("(?:[^"]*(?:""[^"]*)*)"|[^,]*)/

let multiline = #/
    (?<year>\d{4})-
    (?<month>\d{2})-
    (?<day>\d{2})
/#
