module TextUtils

using Mailbox

export html_to_plain_text,
    sanitize_text,
    extract_plain_text


"""
    html_to_plain_text(html::String) -> String

Convert HTML content to plain text.

This function removes HTML tags, decodes HTML entities, and formats the text
while preserving basic structure. It performs the following operations:

- Removes <script> and <style> elements
- Replaces <br> tags with newlines
- Replaces </p> tags with double newlines
- Removes all other HTML tags
- Decodes HTML entities
- Collapses multiple spaces within lines
- Preserves single newlines
- Consolidates multiple newlines into double newlines
- Trims leading and trailing whitespace

# Arguments
- `html::String`: The input HTML content to be converted

# Returns
- `String`: The resulting plain text

# Example
```julia
html = "<p>Hello, <b>world</b>!</p><br><br>How are you?"
plain_text = html_to_plain_text(html)
println(plain_text)
# Output:
# Hello, world!
#
# How are you?
```
"""
function html_to_plain_text(html::String)
    # Dictionary of common HTML entities
    html_entities = Dict(
        "&nbsp;" => " ",
        "&lt;" => "<",
        "&gt;" => ">",
        "&amp;" => "&",
        "&quot;" => "\"",
        "&apos;" => "'",
        "&#39;" => "'"
        # Add more entities as needed
    )

    # Function to decode HTML entities
    function decode_entities(text)
        for (entity, replacement) in html_entities
            text = replace(text, entity => replacement)
        end
        # Handle numeric entities
        text = replace(text, r"&#(\d+);" => m -> Char(parse(Int, m[1])))
        return text
    end

    # Remove script and style elements
    html = replace(html, r"<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>" => "")
    html = replace(html, r"<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>" => "")

    # Replace <br> tags with newlines
    html = replace(html, r"<br\s*/?>|<br\s*/?>" => "\n")

    # Replace </p> tags with double newlines
    html = replace(html, r"</p>" => "\n\n")

    # Remove all other HTML tags
    html = replace(html, r"<[^>]+>" => "")

    # Decode HTML entities
    text = decode_entities(html)

    # Process text line by line
    lines = split(text, "\n")
    processed_lines = String[]
    for line in lines
        # Collapse multiple spaces within each line
        processed_line = replace(line, r"\s+" => " ")
        push!(processed_lines, strip(processed_line))
    end

    # Join lines, preserving single newlines
    text = join(processed_lines, "\n")

    # Consolidate multiple newlines into single newlines
    text = replace(text, r"\n{3,}" => "\n\n")

    # Trim leading and trailing whitespace
    text = strip(text)

    return text
end


"""
    sanitize_text(text::String) -> String

Sanitize a text string by removing extra spaces, consolidating newlines, and replacing HTML entities.

This function performs the following operations:
- Replaces HTML entities (&nbsp;, &lt;, &gt;) with their corresponding characters
- Removes extra spaces within lines
- Consolidates multiple newlines into single newlines
- Removes leading and trailing whitespace

# Arguments
- `text::String`: The input text to be sanitized

# Returns
- `String`: The sanitized text

# Example
```julia
dirty_text = "  Hello &nbsp; &lt;world&gt;!  \n\n\nHow are you?  "
clean_text = sanitize_text(dirty_text)
println(clean_text)
# Output:
# Hello < world>!
# How are you?
```
"""
function sanitize_text(text::String)
    # Define a dictionary of HTML entities to replace
    html_entities = Dict(
        "&nbsp;" => " ",
        "&lt;" => "<",
        "&gt;" => ">"
        # Add more entities here as needed
    )

    # Function to replace HTML entities
    function replace_html_entities(text)
        for (entity, replacement) in html_entities
            text = replace(text, entity => replacement)
        end
        return text
    end

    # Function to remove extra spaces within lines
    function remove_extra_spaces(text)
        return join(strip.(split(text, "\n")), "\n")
    end

    # Function to consolidate multiple newlines
    function consolidate_newlines(text)
        return replace(text, r"\n{2,}" => "\n")
    end

    # Apply all sanitization steps
    sanitized_text = text |>
        replace_html_entities |>
        remove_extra_spaces |>
        consolidate_newlines |>
        strip  # Removes leading and trailing whitespace

    return sanitized_text
end


"""
    extract_plain_text(mail::AbstractMail) -> String

Extract plain text content from an AbstractMail object.

This function recursively processes the email structure, extracting and converting
content to plain text. It handles both single-part (Mail) and multi-part (MultipartMail) emails.

# Arguments
- `mail::AbstractMail`: The email object to process

# Returns
- `String`: The extracted plain text content

# Example
```julia
mail = parse_mail(raw_email_content)
plain_text = extract_plain_text(mail)
println(plain_text)
```
"""
function extract_plain_text(mail::AbstractMail)
    # Helper function to process individual parts of the email
    function process_part(part)
        if part isa AbstractMail
            return extract_plain_text(part)
        elseif isa(part, String)
            headers, content = split_headers_and_body(part)
            content_type = get(headers, "Content-Type", "")
            if startswith(lowercase(content_type), "text/html")
                return html_to_plain_text(content)
            elseif startswith(lowercase(content_type), "text/plain")
                return sanitize_text(content)
            elseif startswith(lowercase(content_type), "multipart/")
                return extract_plain_text(parse_mail(part))
            else
                return ""  # Non-text content, ignore
            end
        else
            return ""  # Unknown part type, ignore
        end
    end

    if mail isa Mail
        headers, content = split_headers_and_body(mail.body)
        content_type = get(mail.headers, "Content-Type", "")
        if startswith(lowercase(content_type), "text/html")
            return html_to_plain_text(content)
        elseif startswith(lowercase(content_type), "text/plain")
            return sanitize_text(content)
        else
            return process_part(mail.body)
        end
    elseif mail isa MultipartMail
        text_parts = String[]
        for part in mail.parts
            text_content = process_part(part)
            if !isempty(text_content)
                push!(text_parts, text_content)
            end
        end
        return join(text_parts, "\n\n")
    else
        error("Unsupported mail type: $(typeof(mail))")
    end
end


end # module TextUtils
