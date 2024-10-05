
using Base64

struct MultipartMail <: AbstractMail
    headers::Dict{String,Any}
    parts::Vector{String}
end

mutable struct Mail <: AbstractMail
    headers::Dict{String,Any}
    body::String
end


"""
    parse_mail(raw_message::Vector{UInt8}) -> Union{Mail, MultipartMail}

Parse a raw email message into a structured format.

This function takes a raw email message as a byte array and parses it into
a `Mail` or `MultipartMail` object, depending on the message structure.

The function performs the following steps:
1. Splits the raw message into lines
2. Parses the headers
3. Extracts the body
4. Handles content transfer encoding (e.g., base64)
5. Processes multipart messages

Parameters:
- `raw_message::Vector{UInt8}`: The raw email message as a byte array

Returns:
- `Mail`: If the message is a simple, single-part email
- `MultipartMail`: If the message is a multipart email

Throws:
- Various exceptions may be thrown during parsing, especially for malformed messages
"""
function parse_mail(raw_message::Vector{UInt8})
    headers = Dict{String,Any}()
    body = ""
    header_done = false
    current_header = ""

    # Convert raw message to string and split into lines
    lines = split(String(raw_message), r"\r?\n")

    # Parse headers
    i = 1
    while i <= length(lines)
        line = lines[i]
        if isempty(strip(line))
            # Empty line indicates end of headers
            header_done = true
            i += 1
            break
        elseif startswith(line, "From ") && isempty(headers)
            # Special handling for mbox "From " line
            headers["Mbox-From"] = String(strip(line))
        elseif startswith(line, " ") || startswith(line, "\t")
            # Continuation of previous header
            if !isempty(current_header) && haskey(headers, current_header)
                if headers[current_header] isa Vector
                    # Append to last element if header is a vector
                    headers[current_header][end] *= " " * strip(line)
                else
                    # Concatenate if header is a string
                    headers[current_header] *= " " * strip(line)
                end
            end
        else
            # New header
            parts = split(line, ":", limit=2)
            if length(parts) == 2
                key, value = String.(strip.(parts))
                current_header = key
                if haskey(headers, key)
                    # Convert to vector if header appears multiple times
                    if headers[key] isa Vector
                        push!(headers[key], value)
                    else
                        headers[key] = [headers[key], value]
                    end
                else
                    headers[key] = value
                end
            end
        end
        i += 1
    end

    # Parse body (everything after headers)
    body = join(lines[i:end], "\n")

    # Handle Content-Transfer-Encoding
    if haskey(headers, "Content-Transfer-Encoding")
        encoding = lowercase(headers["Content-Transfer-Encoding"])
        if encoding == "base64"
            # Attempt to decode base64 content
            try
                body = String(base64decode(strip(body)))
            catch e
                if e isa ArgumentError && occursin("malformed base64 sequence", e.msg)
                    @warn "Failed to decode base64 content. Keeping original content."
                else
                    rethrow(e)
                end
            end
        elseif encoding == "quoted-printable"
            # TODO: Add quoted-printable decoding
        end
    end

    # Handle multipart messages
    if haskey(headers, "Content-Type") && startswith(headers["Content-Type"], "multipart/")
        boundary = extract_boundary(String(headers["Content-Type"]))
        if !isnothing(boundary)
            # Split the body into parts using the boundary
            parts = split_multipart(body, boundary)
            return MultipartMail(headers, parts)
        end
    end

    # Return a single-part mail object
    return Mail(headers, body)
end

# Overload parse_mail to accept a string
parse_mail(raw_message::String) = parse_mail( Vector(codeunits(raw_message)) )

# Overload Mail constructor to accept a string
Mail(raw_message::String) = parse_mail(raw_message)


"""
    extract_boundary(content_type::String) -> Union{String, Nothing}

Extract the boundary string from a multipart Content-Type header.

This function searches for the boundary parameter in the Content-Type
header and returns it if found. The boundary is used to separate different
parts in a multipart email message.

Parameters:
- `content_type::String`: The Content-Type header value

Returns:
- `String`: The extracted boundary string if found
- `Nothing`: If no boundary is found in the Content-Type header

Example:
    content_type = "multipart/mixed; boundary=\"abcdef\""
    boundary = extract_boundary(content_type)  # Returns "abcdef"
"""
function extract_boundary(content_type::String)
    m = match(r"boundary=\"?(.+?)\"?(\s|$)", content_type)
    return isnothing(m) ? nothing : String(m.captures[1])
end

"""
    split_multipart(body::String, boundary::String) -> Vector{String}

Split a multipart email body into its constituent parts using the specified boundary.

This function takes the body of a multipart email message and its boundary string,
and returns a vector of strings, each representing a part of the multipart message.
The function excludes the preamble and epilogue of the multipart message.

Parameters:
- `body::String`: The full body of the multipart email message
- `boundary::String`: The boundary string used to separate parts in the message

Returns:
- `Vector{String}`: A vector containing each part of the multipart message as a separate string

Note: This function assumes that the boundary in the message is prefixed with "--".
"""
function split_multipart(body::String, boundary::String)
    parts = split(body, "--" * boundary)
    return [strip(part) for part in parts[2:end-1]]  # Exclude preamble and epilogue
end
