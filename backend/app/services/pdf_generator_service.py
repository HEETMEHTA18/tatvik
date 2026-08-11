import re
import logging
from fpdf import FPDF

logger = logging.getLogger(__name__)


class PDFResumeGenerator(FPDF):
    def __init__(self):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(12, 12, 12)
        self.set_auto_page_break(auto=False)  # We handle paging manually for columns

    def header(self):
        pass

    def footer(self):
        # Page numbers at bottom
        self.set_y(-10)
        self.set_font("helvetica", "I", 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


class PDFGeneratorService:
    @staticmethod
    def clean_unicode(text: str) -> str:
        """
        Replaces smart quotes, en-dashes, em-dashes, and special bullets with ASCII/Latin-1 equivalents.
        """
        replacements = {
            "\u2018": "'",  # left single quote
            "\u2019": "'",  # right single quote
            "\u201c": '"',  # left double quote
            "\u201d": '"',  # right double quote
            "\u2013": "-",  # en dash
            "\u2014": "-",  # em dash
            "\u2022": "-",  # bullet
            "\u2026": "...",  # ellipsis
            "\u00a0": " ",  # non-breaking space
            "\u200b": "",  # zero-width space
            "Ô": "-",  # common mistranslation of bullet
        }
        for orig, rep in replacements.items():
            text = text.replace(orig, rep)
        # Strip markdown links [text](url) -> text, with bounded quantifiers to prevent ReDoS
        text = re.sub(r"\[([^\]]{1,250})\]\([^)]{1,500}\)", r"\1", text)
        # Convert anything else to Latin-1 safe characters
        return text.encode("latin1", "replace").decode("latin1")

    @staticmethod
    def parse_markdown(markdown_text: str):
        """
        Parses Markdown text into dictionary sections.
        """
        sections = {}
        current_section = "HEADER"
        sections[current_section] = []

        for line in markdown_text.split("\n"):
            line_str = line.strip()
            if not line_str:
                continue

            upper_line = line_str.upper()
            if line_str.startswith("## "):
                heading = line_str[3:].strip().upper()
                current_section = heading
                sections[current_section] = []
            elif (line_str.startswith("### ") or line_str.startswith("**")) and any(
                kw in upper_line
                for kw in [
                    "SUMMARY",
                    "EXPERIENCE",
                    "PROJECTS",
                    "EDUCATION",
                    "SKILLS",
                    "CONTACT",
                ]
            ):
                heading = re.sub(r"[^a-zA-Z\s]", "", line_str).strip().upper()
                current_section = heading
                sections[current_section] = []
            elif line_str.startswith("# "):
                sections["HEADER"].append(line_str)
            else:
                sections[current_section].append(line_str)

        return sections

    @staticmethod
    def parse_header(header_lines):
        """
        Extracts Name, Job Title, and Contact details from the Header section lines.
        """
        name = "Candidate Name"
        title = ""
        contact_parts = []

        for line in header_lines:
            line_str = line.strip()
            if not line_str:
                continue
            if line_str.startswith("#"):
                name = line_str.replace("#", "").strip()
            elif (
                "@" in line_str
                or "|" in line_str
                or any(char.isdigit() for char in line_str)
                and len(line_str) < 100
            ):
                parts = re.split(r"\||•", line_str)
                contact_parts.extend([p.strip() for p in parts if p.strip()])
            else:
                if name == "Candidate Name":
                    name = line_str
                elif not title:
                    title = line_str
                else:
                    contact_parts.append(line_str)

        return name, title, contact_parts

    @classmethod
    def markdown_to_pdf(cls, markdown_text: str) -> bytes:
        """
        Converts tailored resume markdown into an ATS-friendly, professional two-column PDF.
        """
        cleaned_markdown = cls.clean_unicode(markdown_text)
        sections = cls.parse_markdown(cleaned_markdown)
        name, title, contacts = cls.parse_header(sections.get("HEADER", []))

        pdf = PDFResumeGenerator()
        pdf.add_page()

        # 1. Render Header
        pdf.set_xy(12, 12)
        pdf.set_font("helvetica", "B", 22)
        pdf.set_text_color(11, 37, 69)  # Navy Accent
        pdf.cell(118, 9, name, ln=0, align="L")

        # Stack contacts on the right
        contact_y = 12
        pdf.set_font("helvetica", "", 8.5)
        pdf.set_text_color(29, 45, 68)  # Charcoal body text
        for part in contacts:
            pdf.set_xy(135, contact_y)
            pdf.cell(63, 4.5, part, ln=0, align="R")
            contact_y += 4.5

        # Print title under the name
        pdf.set_xy(12, 21)
        pdf.set_font("helvetica", "", 11)
        pdf.set_text_color(92, 103, 125)  # Slate Gray
        pdf.cell(118, 5, title, ln=0, align="L")

        start_y = max(28, contact_y) + 6

        # Draw vertical separator line on the first page
        pdf.set_draw_color(200, 200, 200)
        pdf.set_line_width(0.3)
        pdf.line(131, start_y, 131, 280)

        # Categorize sections into Left and Right Columns
        left_col_sections = []
        right_col_sections = []

        LEFT_COL_KEYWORDS = {
            "WORK EXPERIENCE",
            "EXPERIENCE",
            "PROJECTS",
            "PROFESSIONAL EXPERIENCE",
            "PUBLICATIONS",
            "PROJECTS & EXPERIENCE",
        }

        for sec_title, sec_lines in sections.items():
            if sec_title == "HEADER":
                continue
            is_left = False
            for kw in LEFT_COL_KEYWORDS:
                if kw in sec_title:
                    is_left = True
                    break

            if is_left:
                left_col_sections.append((sec_title, sec_lines))
            else:
                right_col_sections.append((sec_title, sec_lines))

        # Page trackers
        left_page = 1
        right_page = 1
        left_y = start_y
        right_y = start_y

        def check_page_left(needed_height):
            nonlocal left_page, left_y
            if left_y + needed_height > 280:
                left_page += 1
                left_y = 15
                while pdf.page_no() < left_page:
                    pdf.add_page()
                    # Draw vertical separator line on new pages
                    pdf.set_draw_color(200, 200, 200)
                    pdf.set_line_width(0.3)
                    pdf.line(131, 15, 131, 280)
                pdf.page = left_page

        def check_page_right(needed_height):
            nonlocal right_page, right_y
            if right_y + needed_height > 280:
                right_page += 1
                right_y = 15
                while pdf.page_no() < right_page:
                    pdf.add_page()
                    # Draw vertical separator line on new pages
                    pdf.set_draw_color(200, 200, 200)
                    pdf.set_line_width(0.3)
                    pdf.line(131, 15, 131, 280)
                pdf.page = right_page

        # Render Left Column
        for sec_title, sec_lines in left_col_sections:
            pdf.page = left_page
            check_page_left(15)

            pdf.set_xy(12, left_y)
            pdf.set_font("helvetica", "B", 11)
            pdf.set_text_color(11, 37, 69)
            pdf.cell(115, 6, sec_title, ln=1)
            left_y += 6

            pdf.set_draw_color(19, 64, 116)
            pdf.set_line_width(0.4)
            pdf.line(12, left_y, 127, left_y)
            left_y += 3

            for line in sec_lines:
                pdf.page = left_page
                line_str = line.strip().replace("**", "")

                if line.startswith("### "):
                    check_page_left(12)
                    sub = line[4:].strip().replace("**", "")
                    pdf.set_xy(12, left_y)
                    pdf.set_font("helvetica", "B", 9.5)
                    pdf.set_text_color(29, 45, 68)

                    if "|" in sub:
                        parts = sub.split("|")
                        left_text = parts[0].strip()
                        right_text = " | ".join(parts[1:]).strip()
                        pdf.cell(80, 5, left_text)
                        pdf.set_font("helvetica", "B", 8.5)
                        pdf.set_text_color(92, 103, 125)
                        pdf.cell(35, 5, right_text, ln=1, align="R")
                    else:
                        pdf.cell(115, 5, sub, ln=1)
                    left_y += 5

                elif (
                    "|" in line_str
                    and not line.startswith("-")
                    and not line.startswith("*")
                ):
                    check_page_left(8)
                    pdf.set_xy(12, left_y)
                    pdf.set_font("helvetica", "I", 8.5)
                    pdf.set_text_color(92, 103, 125)
                    parts = line_str.split("|")
                    left_text = parts[0].strip()
                    right_text = " | ".join(parts[1:]).strip()
                    pdf.cell(80, 4, left_text)
                    pdf.cell(35, 4, right_text, ln=1, align="R")
                    left_y += 4

                elif (
                    line.startswith("- ")
                    or line.startswith("* ")
                    or line.startswith("Ô ")
                ):
                    bullet_text = line[2:].strip().replace("**", "")
                    approx_lines = max(1, len(bullet_text) // 60)
                    needed = approx_lines * 4.5 + 2
                    check_page_left(needed)

                    pdf.set_xy(12, left_y)
                    pdf.set_font("helvetica", "", 9)
                    pdf.set_text_color(29, 45, 68)
                    pdf.cell(4, 4.5, "-", border=0, ln=0)
                    pdf.multi_cell(111, 4.5, bullet_text, border=0)
                    left_y = pdf.get_y() + 1

                else:
                    if not line_str:
                        continue
                    approx_lines = max(1, len(line_str) // 60)
                    needed = approx_lines * 4.5 + 2
                    check_page_left(needed)

                    pdf.set_xy(12, left_y)
                    pdf.set_font("helvetica", "", 9)
                    pdf.set_text_color(29, 45, 68)
                    pdf.multi_cell(115, 4.5, line_str, border=0)
                    left_y = pdf.get_y() + 1

            left_y += 4

        # Render Right Column
        for sec_title, sec_lines in right_col_sections:
            pdf.page = right_page
            check_page_right(15)

            pdf.set_xy(135, right_y)
            pdf.set_font("helvetica", "B", 11)
            pdf.set_text_color(11, 37, 69)
            pdf.cell(63, 6, sec_title, ln=1)
            right_y += 6

            pdf.set_draw_color(19, 64, 116)
            pdf.set_line_width(0.4)
            pdf.line(135, right_y, 198, right_y)
            right_y += 3

            for line in sec_lines:
                pdf.page = right_page
                line_str = line.strip().replace("**", "")

                if line.startswith("### "):
                    check_page_right(10)
                    sub = line[4:].strip().replace("**", "")
                    pdf.set_xy(135, right_y)
                    pdf.set_font("helvetica", "B", 9.5)
                    pdf.set_text_color(29, 45, 68)
                    pdf.cell(63, 5, sub, ln=1)
                    right_y += 5

                elif (
                    line.startswith("- ")
                    or line.startswith("* ")
                    or line.startswith("Ô ")
                ):
                    bullet_text = line[2:].strip().replace("**", "")
                    approx_lines = max(1, len(bullet_text) // 30)
                    needed = approx_lines * 4.5 + 2
                    check_page_right(needed)

                    pdf.set_xy(135, right_y)
                    pdf.set_font("helvetica", "", 9)
                    pdf.set_text_color(29, 45, 68)
                    pdf.cell(4, 4.5, "-", border=0, ln=0)
                    pdf.multi_cell(59, 4.5, bullet_text, border=0)
                    right_y = pdf.get_y() + 1

                else:
                    if not line_str:
                        continue
                    approx_lines = max(1, len(line_str) // 30)
                    needed = approx_lines * 4.5 + 2
                    check_page_right(needed)

                    pdf.set_xy(135, right_y)
                    pdf.set_font("helvetica", "", 9)
                    pdf.set_text_color(29, 45, 68)
                    pdf.multi_cell(63, 4.5, line_str, border=0)
                    right_y = pdf.get_y() + 1

            right_y += 4

        return bytes(pdf.output())
