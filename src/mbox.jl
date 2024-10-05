

mutable struct MBox <: AbstractMailbox
    path::String
    toc::Union{Dict{Int,Tuple{Int,Int}},Nothing}
end


"""
    MBox(path::String)

Create a new MBox instance with the given path.

# Arguments
- `path::String`: The path to the mailbox file.

# Returns
- `MBox`: A new MBox instance with the given path and an empty table of contents.
"""
function MBox(path::String)
    toc = nothing
    path = abspath(path)
    return MBox(path, toc)
end



"""
    generate_toc(path::String) -> Dict{Int,Tuple{Int,Int}}

Generate a table of contents (TOC) for an mbox file.

This function reads an mbox file and creates a dictionary where:
- Keys are message numbers (starting from 1)
- Values are tuples containing (start_position, length) of each message

Parameters:
- `path::String`: The file path of the mbox file

Returns:
- `Dict{Int,Tuple{Int,Int}}`: A dictionary representing the TOC
"""
function generate_toc(path::String)
    toc = Dict{Int,Tuple{Int,Int}}()
    open(path, "r") do file
        message_count = 0
        start_pos = 0
        current_pos = 0
        for line in eachline(file)
            if startswith(line, "From ")
                # If this isn't the first message, add the previous message to the TOC
                if message_count > 0
                    toc[message_count] = (start_pos, current_pos - start_pos)
                end
                message_count += 1
                start_pos = current_pos
            end
            current_pos = position(file)
        end
        # Add the last message to the TOC
        if message_count > 0
            toc[message_count] = (start_pos, current_pos - start_pos)
        end
    end
    return toc
end


"""
    get_message(mbox::MBox, key::Int) -> Vector{UInt8}

Retrieve a specific message from an MBox.

This function performs the following steps:
1. Ensures the table of contents (TOC) is generated if it doesn't exist.
2. Checks if the requested message key exists in the TOC.
3. Retrieves the start position and length of the message from the TOC.
4. Reads and returns the message content from the mbox file.

Parameters:
- `mbox::MBox`: The MBox object containing the mailbox information.
- `key::Int`: The message number to retrieve.

Returns:
- `Vector{UInt8}`: The content of the requested message as a byte array.

Throws:
- `KeyError`: If the requested message key does not exist in the TOC.
"""
function get_message(mbox::MBox, key::Int)
    # Generate the TOC if it doesn't exist
    if isnothing(mbox.toc)
        mbox.toc = generate_toc(mbox.path)
    end

    # Check if the requested message key exists in the TOC
    if !haskey(mbox.toc, key)
        throw(KeyError(key))
    end

    # Get the start position and length of the message from the TOC
    start_pos, length = mbox.toc[key]

    # Open the mbox file, seek to the message start, and read the message content
    open(mbox.path, "r") do file
        seek(file, start_pos)
        return read(file, length)
    end
end



# Iterators
function Base.iterate(mbox::MBox, state=1)
    if isnothing(mbox.toc)
        mbox.toc = generate_toc(mbox.path)
    end

    if state > length(mbox)
        return nothing
    end

    return (get_message(mbox, state), state + 1)
end

function Base.length(mbox::MBox)
    if isnothing(mbox.toc)
        mbox.toc = generate_toc(mbox.path)
    end
    return length(mbox.toc)
end

Base.firstindex(mbox::MBox) = 1
Base.lastindex(mbox::MBox) = length(mbox)
Base.eltype(::Type{MBox}) = Vector{UInt8}

function Base.getindex(mbox::MBox, i::Int)
    if isnothing(mbox.toc)
        mbox.toc = generate_toc(mbox.path)
    end
    return get_message(mbox, i)
end

function Base.iterate(mbox::MBox, range::UnitRange{Int})
    start, stop = range.start, range.stop
    if start > stop || start < 1 || stop > length(mbox)
        throw(BoundsError(mbox, range))
    end
    return Base.iterate(mbox, start)
end
