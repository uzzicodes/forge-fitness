import type {Metadata} from 'next';
import './globals.css';
export const metadata:Metadata={title:'FORGE · Fitness & Fuel',description:'Train consistently. Fuel your progress. A private food and workout journal.',icons:{icon:'/fitness/favicon.png',apple:'/fitness/icons/Icon-192.png'}};
export default function RootLayout({children}:Readonly<{children:React.ReactNode}>){return <html lang="en"><body>{children}</body></html>}
