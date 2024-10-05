# Mailbox.jl

Simple implementation to parse "mbox" files in Julia. It's not a full implementation of the mbox
format, but it should be enough for extracting individual emails.

## Usage

```julia
using Mailbox

mbox_path = "path/to/mbox/file"
mbox = MBox(mbox_path)

# Get number of mail messages in mbox
println("Total messages: ", length(mbox))

# Fetch the last message
idx = length(mbox)
eml = mbox[idx] |> parse_mail

# Print the headers of the fetched email
println(eml.headers)

```
