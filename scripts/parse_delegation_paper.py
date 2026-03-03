import os
import sys
from pathlib import Path

try:
    import pypdf
except ImportError:
    print("Error: pypdf library is required. Install it with: pip install pypdf")
    sys.exit(1)

def parse_pdf_to_markdown(pdf_path, output_dir):
    """
    Parses a PDF file into markdown files, one per page, in the specified directory.
    """
    pdf_path = Path(pdf_path)
    if not pdf_path.exists():
        print(f"Error: File {pdf_path} not found.")
        return

    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)

    print(f"Reading {pdf_path}...")
    reader = pypdf.PdfReader(pdf_path)
    
    # Create a main summary file
    main_md_content = [f"# {pdf_path.stem}\n"]
    main_md_content.append(f"**Total Pages:** {len(reader.pages)}\n")
    main_md_content.append("## Table of Contents\n")

    for i, page in enumerate(reader.pages):
        page_num = i + 1
        page_text = page.extract_text()
        
        # Save individual page content
        page_filename = f"page_{page_num:02d}.md"
        with open(output_path / page_filename, "w", encoding="utf-8") as f:
            f.write(f"# Page {page_num}\n\n")
            f.write(page_text)
        
        main_md_content.append(f"- [Page {page_num}]({page_filename})")
        print(f"Extracted page {page_num}")

    # Write the index file
    with open(output_path / "index.md", "w", encoding="utf-8") as f:
        f.write("\n".join(main_md_content))

    print(f"\nSuccess! Markdown files created in: {output_dir}")

if __name__ == "__main__":
    # Adjust the path to your local PDF location
    DEFAULT_PDF = "/Users/mp/Downloads/Intelligent AI Delegation.pdf"
    OUTPUT_DIR = "ai_delegation"
    
    target_pdf = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PDF
    parse_pdf_to_markdown(target_pdf, OUTPUT_DIR)
