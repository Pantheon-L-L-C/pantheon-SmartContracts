
hex_string = bytearray.fromhex("244cefae069e3932ed3cd94ee406ca13ff40632971cbd0926113c414eb06f0d9")

values = [
  '244cefae069e3932ed3cd94ee406ca13ff40632971cbd0926113c414eb06f0d9',
  '1178dfe1800792125bd009b9e3b0048e06e1fc1d3d664cf727dcc28bcf5d0ce8',
  '8871ff0aab22bd627b4605592675f55c43c33670fe3efbc5d129e5cb4ae9f057',
  '31899345c4439a44873a85b146554b6c1d25f708ac507dc44534b18172f4d261'
]
new = []
for i in values:
    new.append([bytearray.fromhex(i)])
print(new)