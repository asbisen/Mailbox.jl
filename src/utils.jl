
"""
    split_headers_and_body(part::String) -> Tuple{Dict{String,Any}, String}

Split an email part into headers and body.

This function takes a string representation of an email part and separates it into
headers and body. It identifies the end of the headers by finding the first empty line,
then parses the headers into a dictionary and combines the remaining lines as the body.

Parameters:
- `part::String`: A string containing the email part to be split

Returns:
- `Tuple{Dict{String,Any}, String}`: A tuple containing:
  - A dictionary of headers, where keys are header names and values are header contents
  - A string containing the body of the email part

If no empty line is found to separate headers and body, the function returns an empty
dictionary for headers and the entire input as the body.

Example:
    part = "Subject: Test\r\nFrom: sender@example.com\r\n\r\nThis is the body."
    headers, body = split_headers_and_body(part)
    # headers = Dict("Subject" => "Test", "From" => "sender@example.com")
    # body = "This is the body."
"""
function split_headers_and_body(part::String)
    lines = split(part, r"\r?\n")
    header_end = findfirst(isempty, lines)
    if isnothing(header_end)
        return Dict{String,Any}(), part
    end

    headers = Dict{String,Any}()
    for line in lines[1:header_end-1]
        if ':' in line
            key, value = split(line, ":", limit=2)
            headers[strip(key)] = strip(value)
        end
    end

    body = join(lines[header_end+1:end], "\n")
    return headers, body
end
