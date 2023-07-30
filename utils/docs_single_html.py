import json

"""
This is a script to insert the contents of the manifest.json and catalog.json files into index.html to produce a 
singular index2.html file that is self contained for sharing or serving the documentation.
"""

search_str = 'o=[i("manifest","manifest.json"+t),i("catalog","catalog.json"+t)]'

with open('../target/index.html', 'r', encoding="utf8") as f:
    content_index = f.read()

with open('../target/manifest.json', 'r', encoding="utf8") as f:
    json_manifest = json.loads(f.read())

with open('../target/catalog.json', 'r', encoding="utf8") as f:
    json_catalog = json.loads(f.read())

with open('../target/index2.html', 'w', encoding="utf8") as f:
    new_str = "o=[{label: 'manifest', data: " + json.dumps(json_manifest) + "},{label: 'catalog', data: " + json.dumps(
        json_catalog) + "}]"
    new_content = content_index.replace(search_str, new_str)
    f.write(new_content)