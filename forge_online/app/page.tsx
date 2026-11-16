import {getChatGPTUser,chatGPTSignInPath} from './chatgpt-auth';
import {redirect} from 'next/navigation';
export const dynamic='force-dynamic';
export default async function Home(){
 if(await getChatGPTUser())redirect('/fitness/?mode=account');
 return <main className="forge-setup"><p className="forge-brand">ϟ FORGE</p><h1>Your everyday.<br/>Stronger.</h1><p>Plan your training, log a meal in one message, track water, and build your rank.</p><section><h2>Start your way</h2><p>No account needed to get started. Guest workouts, meals, water, habits and XP stay in this browser.</p><a className="forge-start" href="/fitness/?mode=guest">Continue without signing in →</a><a className="forge-secondary" href={chatGPTSignInPath('/fitness/?mode=account')}>Sign in for cloud sync</a><small>Guest progress stays on this device. Sign-in uses a separate private cloud profile. Export a backup before clearing browser data. Broader Gemini/Groq photo AI requires sign-in; free text references and the small on-device photo matcher work in guest mode.</small></section><a href="/iphone">Add FORGE to your iPhone →</a></main>;
}
