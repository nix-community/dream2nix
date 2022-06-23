#![deny(rust_2018_idioms)]

use indexer::*;

fn main() {
    let settings: Settings = std::env::args()
        .nth(1)
        .and_then(|input_file| serde_json::from_reader(std::fs::File::open(input_file).ok()?).ok())
        .unwrap_or_else(Default::default);

    let mut indexer = Indexer::new(settings).page_callback(Box::new(|page, url| {
        println!("fetching page {page} from '{url}'")
    }));
    
    indexer.write_info();
}
