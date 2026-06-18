import re
from fpdf import FPDF


class PDFResumeGenerator(FPDF):
    def __init__(self):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_margins(15, 15, 15)
        self.set_auto_page_break(auto=True, margin=15)

    def header(self):
        pass

    def footer(self):
        self.set_y(-10)
        self.set_font("helvetica", "I", 8)
        self.set_text_color(128, 128, 128)
        self.cell(0, 10, f"Page {self.page_no()}", align="C")


class PDFGeneratorService:
    @staticmethod
    def markdown_to_pdf(markdown_text: str) -> bytes:
        """
        Converts tailored resume markdown into an ATS-friendly, professional A4 PDF.
        """
        pdf = PDFResumeGenerator()
        pdf.add_page()
        pdf.set_text_color(40, 40, 40)  # Neutral dark gray

        lines = markdown_text.split("\n")

        for line in lines:
            line_str = line.strip()
            if not line_str:
                pdf.ln(2.5)
                continue

            # Title (Name)
            if line_str.startswith("# "):
                title = line_str[2:].strip()
                pdf.set_font("helvetica", "B", 18)
                pdf.set_text_color(20, 40, 80)  # Dark navy accent
                pdf.cell(0, 10, title, ln=True, align="C")
                pdf.set_text_color(40, 40, 40)
                pdf.ln(1)

            # Section Header
            elif line_str.startswith("## "):
                section = line_str[3:].strip()
                pdf.ln(3)
                pdf.set_font("helvetica", "B", 12)
                pdf.set_text_color(20, 40, 80)  # Dark navy accent
                pdf.cell(0, 6, section.upper(), ln=True, align="L")
                pdf.set_text_color(40, 40, 40)

                # Draw a neat line underneath the section header
                pdf.set_draw_color(180, 180, 180)
                pdf.set_line_width(0.3)
                pdf.line(pdf.get_x(), pdf.get_y(), pdf.get_x() + 180, pdf.get_y())
                pdf.ln(2.5)

            # Subsection Title (Job / Role / Company)
            elif line_str.startswith("### "):
                sub = line_str[4:].strip()
                pdf.set_font("helvetica", "B", 10)

                # If there's location/date like "Google | Software Engineer | 2022 - Present"
                if "|" in sub:
                    parts = sub.split("|")
                    left_text = parts[0].strip()
                    right_text = " | ".join(parts[1:]).strip()
                    pdf.cell(110, 5, left_text, align="L")
                    pdf.set_font("helvetica", "I", 9)
                    pdf.cell(70, 5, right_text, ln=True, align="R")
                else:
                    pdf.cell(0, 5, sub, ln=True, align="L")
                pdf.ln(1)

            # Bullet point
            elif line_str.startswith("- ") or line_str.startswith("* "):
                bullet_text = line_str[2:].strip()
                # Remove bold markers '**' for clean PDF text formatting
                clean_text = bullet_text.replace("**", "")

                pdf.set_font("helvetica", "", 9.5)
                pdf.set_x(20)  # Indent
                pdf.cell(
                    4, 5, "-", border=0, ln=0
                )  # Standard clean dash bullet for ATS
                pdf.multi_cell(161, 5, clean_text, border=0)
                pdf.set_x(15)  # Restore margin

            # Contact headers (usually centered under name if it contains email / phone / pipe)
            elif "|" in line_str and pdf.get_y() < 45:
                clean_text = line_str.replace("**", "")
                pdf.set_font("helvetica", "", 9)
                pdf.cell(0, 5, clean_text, ln=True, align="C")

            # General text
            else:
                clean_text = line_str.replace("**", "")
                pdf.set_font("helvetica", "", 9.5)
                pdf.multi_cell(0, 5, clean_text)
                pdf.ln(1)

        # Return binary bytes
        return bytes(pdf.output())
