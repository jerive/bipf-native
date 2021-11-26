const std = @import("std");
const c = @import("c.zig");
const varint = @import("varint.zig");
const constants = @import("constants.zig");
const helpers = @import("helpers.zig");

const ITERATE_ERROR = error {
    NOT_FOUND
};

pub fn iterate(env: c.napi_env, buffer: []u8, start: u32, pred: c.napi_value, js_buffer: c.napi_value) !u32 {
    const tag = varint.decode(buffer, start) catch return ITERATE_ERROR.NOT_FOUND;
    const len = tag.res >> constants.TAG_SIZE;
    const _type = tag.res & constants.TAG_MASK;
    var d = tag.bytes;

    if (_type == constants.OBJECT) {
        while(d < len) {
            const key_start = start + d;
            const key_tag = varint.decode(buffer, key_start) catch return ITERATE_ERROR.NOT_FOUND;
            d += start + key_tag.bytes + (key_tag.res >> constants.TAG_SIZE);
            const value_start = start + d;
            const value_tag = varint.decode(buffer, value_start) catch return ITERATE_ERROR.NOT_FOUND;
            const next_start = value_tag.bytes + (value_tag.res >> constants.TAG_SIZE);
            
            const arg1 = helpers.u32ToJS(env, value_start) catch return ITERATE_ERROR.NOT_FOUND;
            const arg2 = helpers.u32ToJS(env, key_start) catch return ITERATE_ERROR.NOT_FOUND;
            const argv = helpers.create_array(env, 3, "nope") catch return ITERATE_ERROR.NOT_FOUND;
            helpers.set_array_element(env, argv, 0, js_buffer, "err setting arg 0") catch return ITERATE_ERROR.NOT_FOUND;
            helpers.set_array_element(env, argv, 1, arg1, "err setting arg 1") catch return ITERATE_ERROR.NOT_FOUND;
            helpers.set_array_element(env, argv, 2, arg2, "err setting arg 2") catch return ITERATE_ERROR.NOT_FOUND;

            if (helpers.call_function(env, null, pred, 3, argv)) |res| {
                if (helpers.isTruthy(env, res) catch return ITERATE_ERROR.NOT_FOUND) {
                    return start;
                } else {
                    d += next_start;
                }
            } else |err| {
                return err;
            }
        }
        return start;
    } else if (_type == constants.ARRAY) {
        var i: u32 = 0;
        while(d < len) {
            const arg1 = helpers.u32ToJS(env, start + d) catch return ITERATE_ERROR.NOT_FOUND;
            const arg2 = helpers.u32ToJS(env, i) catch return ITERATE_ERROR.NOT_FOUND;
            // const argv = [_]c.napi_value { js_buffer, arg1, arg2 };
            const argv1 = helpers.create_array(env, 3, "nope") catch return ITERATE_ERROR.NOT_FOUND;
            const argv = argv1;
            i += 1;

            if (helpers.call_function(env, null, pred, 3, argv)) |res| {
                if (helpers.isTruthy(env, res) catch return ITERATE_ERROR.NOT_FOUND) {
                    return start;
                } else {
                    const value_tag = varint.decode(buffer, start + d) catch return ITERATE_ERROR.NOT_FOUND;
                    d += value_tag.bytes + (value_tag.res >> constants.TAG_SIZE);
                }
            } else |err| {
                return err;
            }
        }
        return start;
    } else {
        return ITERATE_ERROR.NOT_FOUND;
    }
}