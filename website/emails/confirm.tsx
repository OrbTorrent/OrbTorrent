// The email with the link to confirm a sign-up, in OrbTorrent's paper and
// ink. React Email builds it ahead of time (render.tsx); the Worker puts the
// link in place of {{link}}, and sends it with its subject (src/worker.ts).
import { Body, Button, Column, Container, Head, Heading, Hr, Html, Img, Link, Preview, Row, Section, Text } from "@react-email/components";

const site = "https://orbtorrent.com";

const colours = {
  paper: "#f6f5f1",
  card: "#ffffff",
  ink: "#131316",
  ink2: "#4b4b52",
  ink3: "#606067",
  line: "#e6e1d6",
};
const font = '-apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif';

// Apple Mail and Outlook follow the reader's dark mode with these; Gmail
// darkens the email by itself.
const darkMode = `
  :root { color-scheme: light dark; supported-color-schemes: light dark; }
  @media (prefers-color-scheme: dark) {
    .page, .page > table > tbody > tr > td { background-color: #05070f !important; }
    .card { background-color: #0e1326 !important; border-color: #1e2540 !important; }
    .ink { color: #f3f5ff !important; }
    .ink2 { color: #c7cde6 !important; }
    .ink3 { color: #9aa2c0 !important; }
    .button { background-color: #f3f5ff !important; color: #131316 !important; }
    .rule { border-color: #1e2540 !important; }
  }
`;

export default function Confirm({ link }: { link: string }) {
  return (
    <Html lang="en-GB">
      <Head>
        <meta name="color-scheme" content="light dark" />
        <meta name="supported-color-schemes" content="light dark" />
        <style>{darkMode}</style>
      </Head>
      <Preview>One click, and you'll hear about OrbTorrent's big releases.</Preview>
      <Body className="page" style={{ margin: 0, padding: "40px 16px", backgroundColor: colours.paper, fontFamily: font }}>
        <Container style={{ maxWidth: "480px" }}>
          <Section
            className="card"
            style={{ backgroundColor: colours.card, border: `1px solid ${colours.line}`, borderRadius: "20px", padding: "40px 36px" }}
          >
            {/* The name is words, so it's there when images aren't; the icon beside it is decoration. */}
            <Row>
              <Column style={{ width: "50px", verticalAlign: "middle" }}>
                <Img src={`${site}/icon-192.png`} alt="" width="40" height="40" style={{ display: "block" }} />
              </Column>
              <Column style={{ verticalAlign: "middle" }}>
                <Text className="ink" style={{ margin: 0, fontSize: "17px", lineHeight: "1.2", fontWeight: 600, letterSpacing: "-0.01em", color: colours.ink }}>
                  OrbTorrent
                </Text>
              </Column>
            </Row>
            <Heading
              as="h1"
              className="ink"
              style={{ margin: "28px 0 0", fontSize: "26px", lineHeight: "1.2", fontWeight: 600, letterSpacing: "-0.02em", color: colours.ink }}
            >
              Confirm your email
            </Heading>
            <Text className="ink2" style={{ margin: "14px 0 0", fontSize: "16px", lineHeight: "1.55", color: colours.ink2 }}>
              You asked to hear about OrbTorrent's big releases. Confirm this is your address, and we'll email you only when
              there's a big new version.
            </Text>
            <Button
              href={link}
              className="button"
              style={{
                marginTop: "28px",
                padding: "14px 24px",
                borderRadius: "999px",
                backgroundColor: colours.ink,
                color: colours.paper,
                fontSize: "15px",
                fontWeight: 500,
                textDecoration: "none",
              }}
            >
              Confirm my email
            </Button>
            <Text className="ink3" style={{ margin: "28px 0 0", fontSize: "13px", lineHeight: "1.5", color: colours.ink3 }}>
              Or open this link:
              <br />
              <Link href={link} className="ink3" style={{ color: colours.ink3, wordBreak: "break-all" }}>
                {link}
              </Link>
            </Text>
            <Hr className="rule" style={{ margin: "28px 0 0", borderColor: colours.line }} />
            <Text className="ink3" style={{ margin: "20px 0 0", fontSize: "13px", lineHeight: "1.5", color: colours.ink3 }}>
              The link works for 7 days. If you didn't ask for this, ignore it: you won't hear from us, and the address is
              deleted.
            </Text>
          </Section>
          <Text className="ink3" style={{ margin: "24px 0 0", textAlign: "center", fontSize: "12px", lineHeight: "1.6", color: colours.ink3 }}>
            OrbTorrent, the free, open-source torrent app for the Mac.
            <br />
            <Link href={site} className="ink3" style={{ color: colours.ink3 }}>
              orbtorrent.com
            </Link>
            {" · "}
            <Link href={`${site}/privacy#emails`} className="ink3" style={{ color: colours.ink3 }}>
              Privacy
            </Link>
          </Text>
        </Container>
      </Body>
    </Html>
  );
}

/** The same email as plain text, for mail apps that show only that. */
export function text(link: string): string {
  return `Confirm your email

You asked to hear about OrbTorrent's big releases. To confirm this is your address, open this link:

${link}

After that, we'll email you only when there's a big new version. The link works for 7 days. If you didn't ask for this, ignore it: you won't hear from us, and the address is deleted.

--
OrbTorrent, the free, open-source torrent app for the Mac.
${site}
`;
}
